resource "proxmox_download_file" "debian_lxc" {
  content_type = "vztmpl"
  datastore_id = "local"
  node_name    = var.target_node
  url          = "http://download.proxmox.com/images/system/${var.debian_lxc_template}"
}
