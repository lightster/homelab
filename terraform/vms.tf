# ---------------------------------------------------------------------------
# VMs (Docker host, k3s server + agents) go here.
# Stubbed for now — the LXC example in containers.tf shows the pattern; a VM
# uses proxmox_virtual_environment_vm with a cloud-init disk. Uncomment and
# flesh out when you stand up the Docker Compose VM (hopper) and k3s trio
# (mike / dustin / lucas).
# ---------------------------------------------------------------------------

# resource "proxmox_virtual_environment_vm" "hopper" {
#   name      = "hopper"
#   node_name = var.target_node
#   tags      = ["docker", "terraform"]
#   # cpu { cores = 4; type = "host" }
#   # memory { dedicated = 8192 }
#   # disk { datastore_id = "local-lvm"; interface = "scsi0"; size = 40 }
#   # ... cloud-init initialization block ...
# }
