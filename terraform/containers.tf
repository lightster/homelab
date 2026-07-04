# ---------------------------------------------------------------------------
# Debian LXC template — pulled to the node's `local` storage from the Proxmox
# mirror. Containers depend on this implicitly via template_file_id.
# ---------------------------------------------------------------------------
resource "proxmox_virtual_environment_download_file" "debian_lxc" {
  content_type = "vztmpl"
  datastore_id = "local"
  node_name    = var.target_node
  url          = "http://download.proxmox.com/images/system/${var.lxc_template}"
}

# ---------------------------------------------------------------------------
# postgres01 — Postgres LXC
# Functional name (there is already an "eleven" on the network). One fully
# worked example; copy the block or refactor to for_each over a map once you
# have several with identical shape.
# ---------------------------------------------------------------------------
resource "proxmox_virtual_environment_container" "postgres01" {
  node_name     = var.target_node
  unprivileged  = true
  start_on_boot = true
  tags          = ["postgres", "terraform"]

  cpu {
    cores = 2
  }

  memory {
    dedicated = 2048
    swap      = 512
  }

  disk {
    datastore_id = var.lxc_datastore
    size         = 20
  }

  network_interface {
    name   = "eth0"
    bridge = "vmbr0"
  }

  operating_system {
    template_file_id = proxmox_virtual_environment_download_file.debian_lxc.id
    type             = "debian"
  }

  initialization {
    hostname = "postgres01"

    ip_config {
      ipv4 {
        address = "10.38.194.12/24"
        gateway = var.gateway
      }
    }

    dns {
      servers = [var.pihole_dns]
    }

    user_account {
      keys = local.ssh_public_keys
    }
  }

  # Postgres in an LXC is the right pattern (Docker is not — that goes in a VM).
  # nesting only needed if you run containers *inside* this LXC; off for Postgres.
  features {
    nesting = false
  }
}
