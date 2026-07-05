terraform {
  backend "s3" {
    bucket = "homelab-tfstate"
    key    = "cerebro/terraform.tfstate"
    region = "us-lax-4"

    endpoints = {
      s3 = "https://us-lax-4.linodeobjects.com"
    }

    use_lockfile = true

    # Settings to make the config compatible with Linode Object Storage
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
  }
}
