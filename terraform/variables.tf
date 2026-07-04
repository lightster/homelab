variable "proxmox_endpoint" {
  type        = string
  description = "Proxmox API endpoint"
  default     = "https://cerebro.lan:8006/"
}

variable "state_passphrase" {
  type        = string
  description = "Passphrase for client-side OpenTofu state/plan encryption (PBKDF2 -> AES-GCM)"
  sensitive   = true
}

variable "proxmox_api_token" {
  type        = string
  description = "Proxmox API token in the form user@realm!tokenid=uuid"
  sensitive   = true
}

variable "target_node" {
  type        = string
  description = "Proxmox node name"
  default     = "cerebro"
}

variable "gateway" {
  type        = string
  description = "LAN gateway"
  default     = "10.38.194.38"
}

variable "pihole_dns" {
  type        = string
  description = "Pi-hole resolver IP (mind-flayer, the Raspberry Pi)"
  default     = "10.38.194.10"
}

# Debian LXC template filename. Downloaded to the node's `local` storage by the
# proxmox_virtual_environment_download_file resource in containers.tf, so it does
# not need to be fetched by hand.
variable "lxc_template" {
  type    = string
  default = "debian-13-standard_13.1-2_amd64.tar.zst"
}

variable "lxc_datastore" {
  type    = string
  default = "local-lvm"
}
