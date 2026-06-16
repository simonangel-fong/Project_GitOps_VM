# keypair.tf
resource "tls_private_key" "fleet" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "fleet" {
  key_name   = "${local.project_name}-fleet"
  public_key = tls_private_key.fleet.public_key_openssh

  tags = {
    Name = "${local.project_name}-fleet"
  }
}

resource "local_sensitive_file" "fleet_private_key" {
  content         = tls_private_key.fleet.private_key_pem
  filename        = "${path.module}/keys/${local.project_name}.pem"
  file_permission = "0400"
}
