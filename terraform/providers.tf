provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure  = true # self-signed cert on the PVE host

  ssh {
    agent    = true
    username = "root"
  }
}
