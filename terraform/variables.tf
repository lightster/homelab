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

variable "debian_lxc_template" {
  type    = string
  default = "debian-13-standard_13.1-2_amd64.tar.zst"
}

variable "debian_cloud_image" {
  type        = string
  description = "URL of the Debian cloud image (qcow2) imported for VM disks"
  default     = "https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2"
}

variable "debian_cloud_image_file" {
  type        = string
  description = "File name to store the downloaded cloud image as (keep the .qcow2 extension so Proxmox detects the format on import)"
  default     = "debian-13-genericcloud-amd64.qcow2"
}

variable "lxc_datastore" {
  type    = string
  default = "local-lvm"
}

variable "vm_datastore" {
  type        = string
  description = "Datastore for VM disks"
  default     = "local-lvm"
}

variable "guest_agent_vendor_snippet" {
  type        = string
  description = "Proxmox file ID of the cloud-init vendor snippet that installs qemu-guest-agent at first boot (written to the host by the hypervisor Ansible role)"
  default     = "local:snippets/qemu-guest-agent.yaml"
}

variable "tailscale_oauth_client_id" {
  type        = string
  description = "Tailscale OAuth client ID (Policy File read+write scope) for managing the tailnet policy"
  sensitive   = true
}

variable "tailscale_oauth_client_secret" {
  type        = string
  description = "Tailscale OAuth client secret (Policy File read+write scope) for managing the tailnet policy"
  sensitive   = true
}
