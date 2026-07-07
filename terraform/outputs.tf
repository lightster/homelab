# Inventory-ready view of provisioned guests. The tf-to-inventory script
# consumes this.
output "guests" {
  value = {
    postgres01 = {
      ip    = split("/", proxmox_virtual_environment_container.postgres01.initialization[0].ip_config[0].ipv4[0].address)[0]
      group = "postgres"
    }
  }
}
