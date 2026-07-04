# Bootstrap — one-time setup (homelab)

> Run-once, out-of-band setup that is **not** part of the normal day-to-day flow.
> This is the chicken-and-egg bootstrap: creating the state bucket, minting
> credentials, and the first `tofu init` — all the things a routine
> `tofu apply` assumes already exist.

## Why this lives here and not in the README

The Linode state bucket, the Linode access key, the Proxmox API token, and the
encryption passphrase must all exist **before** OpenTofu can run — so they can't
be created by the OpenTofu that depends on them. This is a manual, run-once
procedure done by a human with account + host access. Day-to-day you never repeat
these steps. Keeping it out of the README avoids implying it's a normal part of
the workflow.

Never commit any secret value.

---

## 1. Create the Linode Object Storage state bucket (out-of-band)

In the Linode (Akamai) Cloud dashboard, create an Object Storage bucket
`homelab-tfstate` on the `us-lax-4` endpoint. (If you use a different region,
update `region` and the `endpoints.s3` URL in `terraform/backend.tf` to match.)
Then **enable object versioning** — the dashboard can't do this, so use the S3
API (with `.env.sh` sourced for creds + checksum vars):

```sh
aws s3api put-bucket-versioning --bucket homelab-tfstate \
  --versioning-configuration Status=Enabled \
  --endpoint-url https://us-lax-4.linodeobjects.com --region us-lax-4
```

Verify it took (expect `{"Status": "Enabled"}`):

```sh
aws s3api get-bucket-versioning --bucket homelab-tfstate \
  --endpoint-url https://us-lax-4.linodeobjects.com --region us-lax-4
```

This is your state-rollback safety net if state is ever corrupted. The bucket is
intentionally **not** managed by OpenTofu — it holds the state file, so managing
it in the state it holds would be a circular bootstrap dependency.

## 2. Create the Linode Object Storage access key

Create an Object Storage access key (ideally limited to the `homelab-tfstate`
bucket). This yields an **Access Key** + **Secret Key** — the S3-compatible creds
the backend uses. Note: Linode rejects the AWS SDK's newer default checksums, so
the env file sets `AWS_REQUEST_CHECKSUM_CALCULATION` /
`AWS_RESPONSE_CHECKSUM_VALIDATION=when_required` (already in `.env.sh.example`).

## 3. Create the Proxmox API identity (on Cerebro)

Do **not** use a `root@pam` token. Create a dedicated, revocable, auditable user
with a role scoped to what the `bpg/proxmox` provider needs. Run on the host:

```sh
# a role with the privileges bpg needs to manage LXCs/VMs
pveum role add Terraform -privs "\
Datastore.Allocate Datastore.AllocateSpace Datastore.AllocateTemplate Datastore.Audit \
Pool.Allocate Pool.Audit Sys.Audit Sys.Console Sys.Modify SDN.Use \
VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.CPU VM.Config.Cloudinit \
VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options \
VM.Migrate VM.PowerMgmt VM.Snapshot \
User.Modify Group.Allocate Realm.AllocateUser Mapping.Audit Mapping.Modify Mapping.Use"

pveum user add terraform@pve
pveum aclmod / -user terraform@pve -role Terraform

# --privsep 0 → the token inherits the user's role (simplest). The secret UUID
# prints ONCE here — copy it straight into .env.sh.
pveum user token add terraform@pve tf --privsep 0
```

The full token value for `.env.sh` is `terraform@pve!tf=<that-uuid>`.

`--privsep 0` matters: with privilege separation *on* (the default) the token has
no permissions until you separately ACL the token itself, which surfaces as
confusing "permission denied" errors. If a later `apply` still hits a permission
wall (some LXC features or host-level tweaks want more), the pragmatic fallback is
`pveum aclmod / -user terraform@pve -role Administrator` — still a separate,
revocable identity, just not least-privilege. Start scoped; widen only if it
actually complains.

## 4. Ensure SSH access to the node (for bpg)

The provider is not purely API-driven: `bpg/proxmox` also SSHes to the node for
file uploads and some disk/template operations. `terraform/providers.tf` uses
`ssh { agent = true, username = "root" }`, so the machine running `tofu` must be
able to reach `root@cerebro.lan` with a key loaded in its ssh-agent:

```sh
ssh root@cerebro.lan true && echo "ssh ok"
```

(A non-root SSH user with scoped `sudo` is possible per the bpg docs, but is more
setup than a single-node homelab usually warrants.)

## 5. Generate the state-encryption passphrase

Generate a strong random passphrase (e.g. `openssl rand -base64 32`). **Store it
in a password manager.** Losing it makes the encrypted state unrecoverable.

## 6. Local env file

Copy the template and fill in the values:

```sh
cp terraform/.env.sh.example terraform/.env.sh
# edit terraform/.env.sh: Linode access key + secret, the state passphrase,
# and the Proxmox token
```

Guest SSH access is separate: add the public key(s) that should have root on the
guests to `terraform/ssh_keys.pub` (one per line). Public keys are non-secret, so
that file is committed — not in `.env.sh`.

`terraform/.env.sh` is gitignored. Load it before running tofu:

```sh
set -a && source terraform/.env.sh && set +a
```

## 7. First init + locking smoke test

```sh
tofu -chdir=terraform init   # connects to Linode, sets up encryption + native locking
tofu -chdir=terraform plan   # should succeed
```

(The Debian LXC template is fetched by `tofu apply` — the
`proxmox_virtual_environment_download_file` resource pulls it to `local` storage,
so there's no manual `pveam` step.)

Then verify locking works while state is still empty and safe: start a `tofu
plan` and, before it finishes, start a second one in another shell — the second
should block on the lock.

---

## Operational notes

### Bringing existing hand-built guests under OpenTofu

The first real `apply` is a convergence step, not pure greenfield — Cerebro's
guests predate this repo. See `CLAUDE.md` §5 for the current delta (notably:
`postgres01` = CT 100 must be destroyed and recreated so TF owns it).

### Rotating credentials later

When the Linode access key or the Proxmox token needs rotating: mint a fresh one,
update it in `terraform/.env.sh`, confirm a `tofu plan` still works, then revoke
the old one. Revoke a Proxmox token with
`pveum user token remove terraform@pve tf`.

### Stale-lock recovery (OpenTofu #3041)

With state encryption + `use_lockfile`, locking (mutual exclusion) works, but a
known open bug means OpenTofu can't read the encrypted lock object's details to
surface a lock ID for `tofu force-unlock`. If a lock gets stuck, delete the
`.tflock` object directly in the Linode Object Storage dashboard, then retry.
