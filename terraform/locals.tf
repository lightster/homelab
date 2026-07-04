locals {
  # Public keys for guest root accounts, read from the committed ssh_keys.pub
  # (one per line; blank lines and #-comments ignored).
  ssh_public_keys = [
    for line in split("\n", file("${path.module}/ssh_keys.pub")) :
    trimspace(line)
    if trimspace(line) != "" && !startswith(trimspace(line), "#")
  ]
}
