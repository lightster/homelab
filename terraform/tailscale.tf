resource "tailscale_acl" "this" {
  overwrite_existing_content = true

  acl = jsonencode({
    groups = {
      "group:lan-admins" = ["lightster@gmail.com"]
    }

    tagOwners = {
      "tag:infra"         = ["group:lan-admins"]
      "tag:subnet-router" = ["group:lan-admins"]
    }

    autoApprovers = {
      routes = {
        "10.38.194.0/24" = ["tag:subnet-router"]
      }
    }

    acls = [
      { action = "accept", src = ["*"], dst = ["*:*"] }
    ]
  })
}

data "tailscale_device" "mind_flayer" {
  hostname = "mind-flayer"
}

resource "tailscale_dns_configuration" "this" {
  nameservers {
    address = one([
      for addr in data.tailscale_device.mind_flayer.addresses :
      addr if !strcontains(addr, ":")
    ])
  }

  override_local_dns = true
  magic_dns          = true
}
