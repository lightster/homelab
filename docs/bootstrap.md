# Bootstrap

During the initial setup of `homelab`, the state file needs to be created in an
S3-compatible bucket. Ideally these instructions will never need to be used
again for this repo, but these instructions exist in case of emergency.

## 1. Create the Linode Object Storage state bucket

In the Linode (Akamai) Cloud dashboard, create an Object Storage bucket
`homelab-tfstate` on the `us-lax-4` endpoint. If you use a different region,
update `region` and the `endpoints.s3` URL in `terraform/backend.tf` to match.

## 2. Create the Linode Object Storage access key

Create an Object Storage access key limited to the `homelab-tfstate`
bucket. This yields an **Access Key** + **Secret Key**—the S3-compatible creds
the backend uses.

## 3. Authenticate the AWS CLI tool

```sh
aws configure --profile homelab

# AWS Access Key ID      -> <Linode access key>
# AWS Secret Access Key  -> <Linode secret key>
# Default region name    -> us-lax-4 (or whatever region the bucket was created in)
# Default output format  -> json
```

## 4. Enable object versioning

Then enable object versioning. The Linode dashboard does not support this, 
so use the S3 API.

```sh
aws s3api put-bucket-versioning \
  --profile homelab \
  --bucket homelab-tfstate \
  --versioning-configuration Status=Enabled \
  --endpoint-url https://us-lax-4.linodeobjects.com \
  --region us-lax-4
```

Verify it took effect:

```sh
aws s3api get-bucket-versioning \
  --profile homelab \
  --bucket homelab-tfstate \
  --endpoint-url https://us-lax-4.linodeobjects.com \
  --region us-lax-4
```

The output should be `{"Status": "Enabled"}`.

## 5. Create the Proxmox API identity (on Cerebro)

Create a dedicated role, user, and API token scoped to what the `bpg/proxmox`
provider needs. Run on the host:

```sh
pveum role add Terraform -privs "\
Datastore.Allocate Datastore.AllocateSpace Datastore.AllocateTemplate Datastore.Audit \
Pool.Allocate Pool.Audit Sys.Audit Sys.Console Sys.Modify SDN.Use \
VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.CPU VM.Config.Cloudinit \
VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options \
VM.GuestAgent.Audit VM.Migrate VM.PowerMgmt VM.Snapshot \
User.Modify Group.Allocate Realm.AllocateUser Mapping.Audit Mapping.Modify Mapping.Use"

pveum user add terraform@pve
pveum aclmod / -user terraform@pve -role Terraform

pveum user token add terraform@pve tf --privsep 0
```

The full token value for the Proxmox API key in `.env.sh` is
`terraform@pve!tf=<uuid-output-by-above-command>`.

6. Upload SSH key to Cerebro

`bgp/proxmox` needs SSH access for some operations, so upload your SSH key to
the server:

```sh
ssh-copy-id -i ~/.ssh/id_file.pub ssh-copy-id root@cerebro.lan
```

## 6. Generate the state-encryption passphrase

Generate a strong random passphrase (e.g. `openssl rand -base64 32`). Store the
random passphrase in 1Password. Losing the passphrase makes the encrypted state
unrecoverable.

## 7. Create the Tailscale credentials

In the Tailscale admin console, under **Settings > Trust credentials**, create
an OAuth client for Terraform with these scopes, and nothing else:

- **Policy File**: Read + Write (`tailscale_acl`)
- **DNS**: Read + Write (`tailscale_dns_configuration`)
- **Devices: Core**: Read (looks up Mind Flayer's tailnet address)

Its ID and secret go in `terraform/.env.sh`.

Ansible enrolls nodes with auth keys, created under **Settings > Keys**. A
tagged key only enrolls a node that requests exactly the key's tags, so there
is one key per tag set. Tags must exist in the tailnet policy before a key can
carry them, so create these after the first `make apply` has pushed the ACL.

| Variable (`ansible/.env.sh`)      | Tags                             | Used by        |
| --------------------------------- | -------------------------------- | -------------- |
| `TAILSCALE_INFRA_AUTHKEY`         | `tag:infra`                      | Mind Flayer    |
| `TAILSCALE_SUBNET_ROUTER_AUTHKEY` | `tag:infra`, `tag:subnet-router` | Cerebro        |
| `TAILSCALE_PERSONAL_AUTHKEY`      | none (owned by your user)        | bob            |

Make the keys reusable so a rebuilt host can re-enroll without a new key. Keys
expire after about 90 days; an already-enrolled node is unaffected, but
re-enrolling needs a current key.

## 8. Local env files

Copy the templates and fill in the values:

```sh
cp terraform/.env.sh.example terraform/.env.sh
cp ansible/.env.sh.example ansible/.env.sh
```

Copy these working `.env.sh` files into 1Password.

## 9. Follow steps in README.md

The steps in README.md for deploying should now work.

## Rebuilding Mind Flayer

Mind Flayer serves the LAN's DHCP and is the tailnet's only DNS nameserver.
While it is down, LAN devices keep their current leases but cannot renew, and
tailnet devices lose DNS entirely. To restore DNS on a device in the meantime,
disconnect it from Tailscale; to restore it tailnet-wide, set
`override_local_dns = false` in `terraform/tailscale.tf` and `make apply`.

1. In the Tailscale admin console, remove the old `mind-flayer` machine.
   Otherwise the rebuilt Pi enrolls under a different name, or Terraform
   resolves the dead node's address and points the tailnet's DNS at it.
2. Flash Debian 13 (Raspberry Pi OS) with user `lightster`, SSH enabled, and a
   key from `ssh_keys.pub` authorized. Give it the static address
   `10.38.194.10`.
3. Install Pi-hole with its installer. The `pihole` role configures an existing
   install; it does not install Pi-hole.
4. Run `make pihole ARGS=--ask-become-pass`. `lightster` needs a sudo password
   until this first run installs passwordless sudo. The run restores Pi-hole's
   DNS, DHCP, and admin password from the repo and enrolls the Pi on the
   tailnet.
5. Run `make plan` and `make apply` so the tailnet's DNS points at the Pi's
   new tailnet address.
