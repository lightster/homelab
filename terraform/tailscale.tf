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
