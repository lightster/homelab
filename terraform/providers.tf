provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure  = true # self-signed cert on the PVE host

  # bpg needs SSH to the node for a handful of operations (file uploads, some
  # disk ops). Uses your ssh-agent by default.
  ssh {
    agent    = true
    username = "root"
  }
}
