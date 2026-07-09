resource "proxmox_download_file" "debian_cloud" {
  content_type = "import"
  datastore_id = "local"
  node_name    = var.target_node
  url          = var.debian_cloud_image
  file_name    = var.debian_cloud_image_file
}

resource "proxmox_virtual_environment_vm" "bob" {
  name      = "bob"
  node_name = var.target_node
  on_boot   = true
  tags      = ["dev", "terraform"]

  agent {
    enabled = true
  }

  cpu {
    cores = 6
    type  = "host"
  }

  memory {
    dedicated = 16384
  }

  scsi_hardware = "virtio-scsi-single"

  disk {
    datastore_id = var.vm_datastore
    import_from  = proxmox_download_file.debian_cloud.id
    interface    = "scsi0"
    size         = 100
    iothread     = true
    discard      = "on"
    ssd          = true
  }

  serial_device {}

  network_device {
    bridge = "vmbr0"
  }

  initialization {
    vendor_data_file_id = var.guest_agent_vendor_snippet

    ip_config {
      ipv4 {
        address = "10.38.194.13/24"
        gateway = var.gateway
      }
    }

    dns {
      servers = [var.pihole_dns]
    }

    user_account {
      username = "lightster"
      keys     = local.ssh_public_keys
    }
  }
}
