# Inventory-ready view of provisioned guests. The tf-to-inventory script
# consumes this.
output "guests" {
  value = {
    postgres01 = {
      ip    = split("/", proxmox_virtual_environment_container.postgres01.initialization[0].ip_config[0].ipv4[0].address)[0]
      group = "postgres"
      user  = "root"
    }
    garage01 = {
      ip    = split("/", proxmox_virtual_environment_container.garage01.initialization[0].ip_config[0].ipv4[0].address)[0]
      group = "garage"
      user  = "root"
    }
    bob = {
      ip    = split("/", proxmox_virtual_environment_vm.bob.initialization[0].ip_config[0].ipv4[0].address)[0]
      group = "dev"
      user  = "lightster"
    }
    rift = {
      ip    = split("/", proxmox_virtual_environment_vm.rift.initialization[0].ip_config[0].ipv4[0].address)[0]
      group = "apps"
      user  = "lightster"
    }
  }
}
