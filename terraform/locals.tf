locals {
  ssh_public_keys = [
    for line in split("\n", file("${path.module}/ssh_keys.pub")) :
    trimspace(line)
    if trimspace(line) != "" && !startswith(trimspace(line), "#")
  ]
}
