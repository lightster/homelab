# One tunnel carries all public traffic into rift. Apps attach hostnames by
# pointing a CNAME at <tunnel id>.cfargotunnel.com from their own zones, which
# must be in this Cloudflare account.
resource "cloudflare_zero_trust_tunnel_cloudflared" "rift" {
  account_id = var.cloudflare_account_id
  name       = "rift"
  config_src = "cloudflare"

  lifecycle {
    # A new tunnel has a new ID, breaking every CNAME that points at it.
    prevent_destroy = true
  }
}

# Every hostname goes to Traefik, which routes by Host header, so adding an
# app never requires a tunnel change.
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "rift" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.rift.id

  config = {
    ingress = [
      { service = "http://traefik.kube-system.svc.cluster.local:80" },
    ]
  }
}

data "cloudflare_zero_trust_tunnel_cloudflared_token" "rift" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.rift.id
}
