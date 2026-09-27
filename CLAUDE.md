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
- `make pihole` — run the `pihole.yml` playbook against Mind Flayer. Pass extra
  `ansible-playbook` flags with `ARGS`, e.g. `make pihole ARGS="--check --diff"`

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

Mind Flayer is bare metal and lives in the hand-written inventory; `make pihole`
configures it with the `pihole` role, which manages a declared subset of
`pihole.toml`. Mind Flayer is also the tailnet's only DNS nameserver
(`tailscale_dns_configuration` in `tailscale.tf`, with local DNS overridden).
Because Terraform reads Mind Flayer's tailnet address, a rebuilt Pi must be
enrolled with `make pihole` **before** `make plan`/`make apply` — the one
place where Ansible runs ahead of Terraform. The full rebuild procedure is in
`docs/bootstrap.md`.

### LXC gotchas

Guest containers are minimal/unprivileged Debian LXCs with **no `sudo`**. The
`acl` package is installed so `su` works. Keep this in mind when adding guest
roles.

## Secrets & state

- **`.env.sh` files are git-ignored**; only `*.env.sh.example` templates are
  committed. `terraform/.env.sh` holds Linode Object Storage (S3 state backend)
  creds, the state-encryption passphrase, and the Proxmox + Tailscale API
  credentials, exported as `TF_VAR_*`. `ansible/.env.sh` holds the Ansible Vault
  password and the Tailscale auth keys, which rotate ~90 days:
  `TAILSCALE_INFRA_AUTHKEY` (`tag:infra`, the default for infrastructure
  nodes) and `TAILSCALE_SUBNET_ROUTER_AUTHKEY` (`tag:infra` +
  `tag:subnet-router`, used by Cerebro). A node must request exactly its key's
  tags.
- **Terraform state** lives in a Linode Object Storage bucket
  (`homelab-tfstate`, S3-compatible) and is **client-side encrypted** with a
  PBKDF2->AES-GCM passphrase (`encryption.tf`). Losing `TF_VAR_state_passphrase`
  makes state unrecoverable. `.terraform.lock.hcl` **is** committed on purpose.
- **Ansible Vault**: `ansible/inventory/group_vars/all/vault.yml` **is** committed
  (encrypted). `vault_pass.sh` feeds the password from `ANSIBLE_VAULT_PASSWORD`.
  Vaulted values are referenced via `vault_*` vars in `vars.yml`.
- One-time backend/identity bootstrap (creating the bucket, Proxmox API token,
  etc.) is documented in `docs/bootstrap.md` — not part of the normal loop.
