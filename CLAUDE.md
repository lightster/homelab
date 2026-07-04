# CLAUDE.md — homelab project context

Context for Claude Code working in this repo. The goal right now is to
**converge what physically exists on Cerebro with what this repo declares**,
then keep them in sync going forward. Much of the current infrastructure was
stood up by hand before the repo existed, so the near-term task is adoption
(import + reconcile), not greenfield creation.

---

## 1. What this repo is

IaC for a single-node Proxmox homelab. Two layers, two tools, sibling dirs:

- `terraform/` — **provisioning** (which LXCs/VMs exist + specs), via the
  `bpg/proxmox` provider against the Proxmox API. Run with **OpenTofu** (`tofu`);
  state lives in a remote, client-side-encrypted S3 backend.
- `ansible/` — **configuration** (host sysctl, Tailscale, in-guest bootstrap).
- `scripts/tf-to-inventory.sh` — regenerates `ansible/inventory/10-guests.ini`
  from `terraform output`, so the inventory is downstream of real provisioning.

See `README.md` for the layout and quick-start.

---

## 2. The machine: Cerebro

- **Hardware:** Minisforum MS-A2 — Ryzen 9 9955HX, 64 GB DDR5-5600, 1 TB SSD.
  A 2 TB NVMe carried over from a stalled DeskMini X600 build is the one part
  worth reusing; that DeskMini is out for RMA and may later become a 2nd node.
- **Role:** bare-metal Proxmox VE 9 hypervisor. Host is **Cerebro**,
  hostname **`cerebro.lan`**.
- **Proxmox repos:** enterprise repos disabled, no-subscription repo added
  (cosmetic "No valid subscription" popup remains; functionally fine).
- **Firmware:** on **1.0.2**. 1.0.3 was deliberately skipped (changelog offered
  nothing useful; it hides "Above 4G Decoding", mildly bad for PCIe passthrough).
- **BIOS decisions:**
  - TjMAX &rarr; 78 **deferred** (comfort/noise, not safety). Sequencing rule:
    flash firmware first, *then* apply BIOS settings (a flash resets BIOS to
    defaults).
  - X710 10 GbE disable path (when wanted): `Advanced -> Onboard Devices
    Settings -> PCI-E Port -> X710 LAN -> Disabled` (NOT the LED toggle).
  - Fan profile quiet/auto; M.2 slots can go PCIe 4.0 x4.
- **Windows OEM license** is UEFI-embedded (MSDM ACPI table); extractable from
  the Proxmox host with `xxd /sys/firmware/acpi/tables/MSDM | tail` if a Windows
  VM is ever wanted. Not needed for anything currently.

> Note: some older chats called the host "Hawkins." That is stale.
> **Cerebro is the host.** See naming rules below.

---

## 3. Networking

- **LAN:** `10.38.194.0/24`. Cerebro static IP **`10.38.194.11/24`**;
  gateway **`10.38.194.38`** (verify against the live host).
- **DNS + DHCP:** a Raspberry Pi named **`mind-flayer`** at **`10.38.194.10`**
  runs **Pi-hole** (both DNS and DHCP). Pi-hole holds a local record for
  `cerebro.lan`. Repo `var.pihole_dns` is set to `10.38.194.10`.
- **ISP:** Google Fiber with a **real public IPv4** (no CGNAT).
- **Tailscale** — base install is up on Cerebro (remote Proxmox-UI access was
  confirmed earlier):
  - Cerebro tailnet IP: **`100.105.232.80`**. Key expiry disabled in the admin
    console.
  - **Verified 2026-07-03 — subnet routing is NOT set up:** `net.ipv4.ip_forward`
    is `0` and nothing persisted it (no `/etc/sysctl.d/99-tailscale.conf`), and
    Cerebro advertises only its own `/32` (no `10.38.194.0/24` in AllowedIPs). The
    `group:lan-admins` ACL is likewise unconfirmed. When subnet routing is wanted:
    enable forwarding (the `common` role does this), set `tailscale_set_args` to
    `--advertise-routes=10.38.194.0/24`, approve the route, and set the ACL.
  - ACLs live in the Tailscale admin console — **out of band from this repo.**
  - Planned: Tailscale **exit node** for streaming while traveling.

---

## 4. Naming convention (read before naming anything)

Stranger Things theme, applied as a **mix**: physical/infra devices tend to get
character names, workload nodes get functional names. Known-real names:

- **`Cerebro`** — the Proxmox host (`cerebro.lan`), at `10.38.194.11`.
- **`mind-flayer`** — the Raspberry Pi running Pi-hole, at `10.38.194.10`.
- **`postgres01`** — the Postgres LXC, at `10.38.194.12` (functional name).

Rules:
- **Do NOT** name homelab guests **`Vecna`** or **`Hawkins`** — those are the
  user's Macs (work and personal), predate the homelab, and are not homelab
  hosts.
- There is already an **`eleven`** on the network — do not use that name for a
  new guest. The tailnet also carries **`hawkins`** (the user's Mac) and
  **`demogorgon`** (an iOS device) as clients — not homelab guests, don't reuse
  either name. The skeleton's other placeholder names (`hopper`,
  `mike`/`dustin`/`lucas` for the Docker VM and k3s nodes) are **not decisions**;
  pick functional or clear character names when those are actually built.

---

## 5. Current actual state vs. what the repo declares (the convergence delta)

**Nothing is in Terraform state yet.** Cerebro and its guests exist but were
created by hand / the Proxmox UI. A naive `terraform apply` would try to CREATE
duplicates. The core convergence work:

| Reality on Cerebro | Repo now declares | Reconciliation |
|---|---|---|
| `postgres01` = **CT 100, running.** PG **18** is installed (default `main` cluster online on 5432) but holds **no user data** — only `postgres`/`template0`/`template1` (verified 2026-07-03) | LXC `postgres01` @ `10.38.194.12` | **Destroy CT 100 and recreate from the repo** (`pct destroy 100`, then `terraform apply`) — chosen over `terraform import` because the cluster is dataless, so a clean-provenance rebuild beats adopting a hand-built spec. A `postgres` Ansible role still needs writing and must reinstall PG. |
| IPv4 forwarding — **confirmed OFF** (`net.ipv4.ip_forward = 0`, verified 2026-07-03); nothing persisted it, no `99-tailscale.conf` | `common` role sets `net.ipv4.ip_forward` via `ansible.posix.sysctl` | No duplicate to reconcile — the `common` role establishes it cleanly (writes `/etc/sysctl.conf`). |
| Tailscale up, but **subnet route confirmed NOT advertised** (Cerebro AllowedIPs = own `/32` only, verified 2026-07-03); `group:lan-admins` ACL still unconfirmed | `tailscale` role runs `up` (login) + `set` (settings); no advertise-routes in defaults | To enable: set `tailscale_set_args = --advertise-routes=10.38.194.0/24`, approve the route in the console, set the ACL (out of band). Needs `ip_forward=1` first. |
| Docker Compose VM (in progress / planned) | `vms.tf` stub only | Flesh out `proxmox_virtual_environment_vm` when the VM is real; import only if it already exists. |
| Pi-hole (`mind-flayer`) at `10.38.194.10` | `var.pihole_dns = 10.38.194.10` | Value set correctly; confirm reachable. |

**First moves for Claude Code:** the host was enumerated on 2026-07-03 (see the
verified notes above); re-check with `pct list`, `qm list`, `tailscale status`,
`sysctl net.ipv4.ip_forward` if state may have drifted. `postgres01` (CT 100) is
dataless, so the plan is destroy-and-recreate via TF + Ansible (not import). For
anything that later carries real state or config, `terraform import` it before
`apply` so TF adopts rather than duplicates. Verify the live host rather than
trusting this doc where they disagree — this file is a starting map, the host is
ground truth.

---

## 6. Architecture decisions + rationale (the "why" matters to this user)

- **Postgres in an LXC; Docker in a VM.** Docker-inside-LXC is the wrong pattern
  (nesting / keyctl issues), so Docker Compose lives in a VM. Postgres LXC does
  not need `nesting`.
- **Proxmox overhead is minimal** for CPU-bound work; the levers are VirtIO SCSI
  single, VirtIO NIC, `cpu type = host`, right cache modes, and **ballooning off
  for DB guests**.
- **k3s topology (decided):** single **server** VM (SQLite datastore, owns the
  control plane) + **two agent** VMs; all three schedulable. Single physical
  node, **for learning, not HA.** SQLite is a local file on the server VM and
  supports exactly one server by design.
- **Quorum math is a hard constraint.** Two physical nodes cannot achieve
  etcd/Raft fault tolerance no matter how many VMs are spread across them —
  losing one physical box always removes exactly half the voters. True HA later
  would need a 3rd voter; the Pi-hole Pi is technically viable (USB SSD, not SD;
  taint it; use static/Tailscale IPs, never Pi-hole DNS, to avoid a
  resolver-is-also-tiebreaker dependency loop).
- **Pi-hole must never be a dependency of cluster quorum** (circular failure).
- **Observability:** leaning **SigNoz** (OpenTelemetry-native, unified
  traces+metrics, Docker Compose, closest OSS Datadog-APM analog; ClickHouse
  backend is memory-hungry). Grafana + Tempo is the noted alternative.
- **Public exposure:** reverse proxy (**Caddy/Traefik**) + **Cloudflare**
  (Tunnel, or port-forward + DDNS) is the path for durable public services.
  **Tailscale Funnel ruled out** for durable public services given the real
  public IP (fine for throwaway demos / webhooks only). Migrating current public
  workloads off Heroku/Linode is the eventual driver.

---

## 7. On the horizon / deferred

- Stand up the core stack: Postgres LXC (exists), Docker Compose VM, then the
  k3s learning trio.
- TjMAX 78 and HA-k3s topology intentionally deferred with clear sequencing.
- DeskMini X600 RMA outcome pending &rarr; decides one-node vs two-node future.

---

## 8. Repo conventions & guardrails

- **Do NOT template into `/etc/pve`** — that is pmxcfs (a replicated DB).
  Proxmox-native config (storage, users, firewall, cluster) goes through the
  API / `pvesh` / `qm` / `pct`, never file templating. Generic Debian-host
  config (sysctl, apt, ssh, tailscale) is fair game.
- **State lives in a remote, client-side-encrypted OpenTofu backend** — S3 on
  Linode Object Storage (bucket `homelab-tfstate`, key `cerebro/terraform.tfstate`),
  encrypted PBKDF2 → AES-GCM via `var.state_passphrase`. Local `*.tfstate` is still
  gitignored as a backstop. Secrets (Linode S3 keys, the state passphrase, the
  Proxmox token) live in `terraform/.env.sh` (gitignored); commit only
  `.env.sh.example`. There is no `terraform.tfvars` — everything is `.env.sh` +
  `TF_VAR_*`, mirroring the `tinyprint/infra` setup. Guest SSH public keys are
  non-secret and live in the committed `terraform/ssh_keys.pub` (one per line).
- **Ansible secrets** go in `ansible/inventory/group_vars/all/vault.yml`
  (committed **encrypted** via `ansible-vault`); the `.example` is plaintext and
  non-secret.
- **Pin the `bpg/proxmox` provider** to the current release — bumped to `~> 0.111`
  on 2026-07-03 (latest at the time; was a stale `~> 0.66`). Re-check the registry
  when revisiting. The `.terraform.lock.hcl` is committed to pin checksums.
- Prefer the Terraform &rarr; outputs &rarr; Ansible inventory handoff over TF
  provisioners.

---

## 9. Working style

The user wants the **reasoning behind constraints**, not just the recommendation;
works incrementally and stress-tests failure/edge cases before committing.
Direct, technically precise answers preferred. Comfortable deferring
optimizations when the sequencing rationale is explicit.
