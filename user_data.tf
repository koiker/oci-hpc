locals {
  controller_config = templatefile("${path.module}/config.controller", {
    key = tls_private_key.ssh.private_key_pem
  })

  config = templatefile("${path.module}/config.hpc", {})
}


