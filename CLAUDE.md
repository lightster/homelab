# CLAUDE.md

Infrastructure-as-code for a personal homelab. Two named machines: **Cerebro**
(Minisforum MS-A2 running Proxmox VE) and **Mind Flayer** (Raspberry Pi running
Pi-hole as LAN DNS at `10.38.194.10`). The LAN subnet is `10.38.194.0/24`.

## Commands

All workflows go through the `Makefile`, which sources the appropriate
`.env.sh` and `cd`s into the tool directory for you:

- `make init` — `tofu init` (first-time / after backend changes)
- `make plan` / `make apply` — OpenTofu plan / apply
- `make inventory` — regenerate `ansible/inventory/10-guests.ini` from Terraform outputs
- `make host` — run the `host.yml` playbook against Cerebro (implies `make inventory`)
- `make guests` — run the `guests.yml` playbook against the guests (implies `make inventory`)

There is no test suite or linter. `tofu plan` and Ansible's own idempotency
(re-run `make host` / `make guests`) are the verification loop.

## Architecture

Provisioning is a two-stage pipeline; **Terraform provisions, Ansible configures**:

1. **Terraform (`terraform/`)** talks to the Proxmox API (`bpg/proxmox`) to
   create guests (LXC containers in `containers.tf`, VMs stubbed in `vms.tf`)
   and manages the Tailscale tailnet ACL (`tailscale.tf`). Guest IPs are
   statically assigned in the resource definitions.
2. **`scripts/tf-to-inventory.sh`** bridges the two stages: it reads the
   Terraform `guests` output (`outputs.tf`) and writes the generated,
   git-ignored `ansible/inventory/10-guests.ini`. When you add a guest, add it
   to the `guests` output so Ansible can see it.
3. **Ansible (`ansible/`)** configures the host and guests over SSH. Inventory
   is split: `inventory/00-static.yml` (hand-written, the Proxmox host) plus the
   generated `10-guests.ini`. `playbooks/host.yml` → `hypervisor` role;
   `playbooks/guests.yml` → per-service roles (e.g. `postgres`).

Networking is unified by **Tailscale**: the `hypervisor` role enrolls nodes and
Cerebro advertises the LAN subnet as a subnet router, so the whole
`10.38.194.0/24` is reachable over the tailnet. Terraform's `autoApprovers`
auto-approves that route for `tag:subnet-router`.

### LXC gotchas

Guest containers are minimal/unprivileged Debian LXCs with **no `sudo`**. The
`acl` package is installed so `su` works. Keep this in mind when adding guest
roles.

## Secrets & state

- **`.env.sh` files are git-ignored**; only `*.env.sh.example` templates are
  committed. `terraform/.env.sh` holds Linode Object Storage (S3 state backend)
  creds, the state-encryption passphrase, and the Proxmox + Tailscale API
  credentials, exported as `TF_VAR_*`. `ansible/.env.sh` holds the Ansible Vault
  password and the ephemeral Tailscale auth key (`TAILSCALE_INFRA_AUTHKEY`,
  rotates ~90 days).
- **Terraform state** lives in a Linode Object Storage bucket
  (`homelab-tfstate`, S3-compatible) and is **client-side encrypted** with a
  PBKDF2->AES-GCM passphrase (`encryption.tf`). Losing `TF_VAR_state_passphrase`
  makes state unrecoverable. `.terraform.lock.hcl` **is** committed on purpose.
- **Ansible Vault**: `ansible/inventory/group_vars/all/vault.yml` **is** committed
  (encrypted). `vault_pass.sh` feeds the password from `ANSIBLE_VAULT_PASSWORD`.
  Vaulted values are referenced via `vault_*` vars in `vars.yml`.
- One-time backend/identity bootstrap (creating the bucket, Proxmox API token,
  etc.) is documented in `docs/bootstrap.md` — not part of the normal loop.
