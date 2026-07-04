terraform {
  encryption {
    key_provider "pbkdf2" "k" {
      passphrase = var.state_passphrase
    }

    method "aes_gcm" "m" {
      keys = key_provider.pbkdf2.k
    }

    state {
      method = method.aes_gcm.m
    }

    plan {
      method = method.aes_gcm.m
    }
  }
}
