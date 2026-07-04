# homelab

Infrastructure-as-code for **Cerebro** (Minisforum MS-A2, Proxmox VE).
Stranger Things naming convention: the host is Cerebro; guests are characters.

Two layers, two tools:

- **`terraform/`** — *provisioning*. Declares which LXCs/VMs exist and to what spec,
  via the `bpg/proxmox` provider (run with **OpenTofu**) talking to the Proxmox API.
  State lives in a remote, client-side-encrypted S3 backend (Linode Object Storage).
- **`ansible/`** — *configuration*. Mutates machines that already exist: host sysctl
  (IPv4 forwarding), Tailscale, in-guest package bootstrap, etc.

The seam between them: `scripts/tf-to-inventory.sh` reads `terraform output` and writes
`ansible/inventory/10-guests.ini`, so the inventory is always downstream of what was
actually provisioned.

## Layout

```
homelab/
├── terraform/           # provisioning (bpg/proxmox)
├── ansible/             # configuration
│   ├── inventory/
│   │   ├── 00-static.yml    # Cerebro (the host) — hand-maintained
│   │   └── 10-guests.ini    # GENERATED from terraform outputs (gitignored)
│   └── roles/{common,tailscale,...}
├── scripts/tf-to-inventory.sh
├── docs/                # setup checklists, topology notes
└── Makefile
```

## Quick start

> **Before the first apply — reconcile, don't duplicate.** Cerebro's guests were
> built by hand before this repo existed and nothing is in Terraform state yet, so
> a cold `terraform apply` will try to *create* resources that already exist and
> collide on name/IP (e.g. the empty hand-built `postgres01` at `10.38.194.12`).
> Destroy the empty container first and let Terraform recreate it, or
> `terraform import` anything already carrying real state. See `CLAUDE.md` §5.

One-time prerequisites (state bucket, Linode + Proxmox credentials, first init)
are a separate run-once procedure — see [`docs/bootstrap.md`](docs/bootstrap.md).

```bash
# 0. secrets — backend creds, encryption passphrase, provider token
cp terraform/.env.sh.example terraform/.env.sh   # fill in (gitignored)
set -a && source terraform/.env.sh && set +a

# 1. provision — state lives in the encrypted Linode S3 backend
tofu -chdir=terraform init
tofu -chdir=terraform apply

# 2. regenerate the ansible inventory from what got built
./scripts/tf-to-inventory.sh

# 3. configure the host
cd ansible && ansible-playbook playbooks/host.yml --ask-vault-pass
```

Or use the `Makefile`: `make apply`, `make inventory`, `make host` (each sources
`terraform/.env.sh` for you).

## Secrets

- **State backend** — OpenTofu state *and* plan live in Linode Object Storage
  (S3-compatible, bucket `homelab-tfstate`), **client-side encrypted** (PBKDF2 →
  AES-GCM) with `TF_VAR_state_passphrase`. Backend keys and provider secrets go in
  `terraform/.env.sh` (gitignored); commit only `.env.sh.example`. Local
  `*.tfstate` is gitignored as a backstop.
- **Ansible** uses Vault: `ansible/inventory/group_vars/all/vault.yml` is committed
  *encrypted*. Create it from the example with `ansible-vault create`.

Before your first push: `git status` and confirm no `*.tfstate`, no `.env.sh`,
and that `vault.yml` is ciphertext.
