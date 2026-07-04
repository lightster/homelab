terraform {
  backend "s3" {
    bucket = "homelab-tfstate"
    key    = "cerebro/terraform.tfstate"
    region = "us-lax-4"

    endpoints = {
      s3 = "https://us-lax-4.linodeobjects.com"
    }

    use_lockfile = true # native locking via conditional writes (If-None-Match)

    # Linode Object Storage is not AWS — skip AWS-specific preflight checks:
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true # Linode rejects the newer default checksum headers
  }
}
