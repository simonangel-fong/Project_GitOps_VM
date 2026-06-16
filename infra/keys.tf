resource "aws_key_pair" "admin" {
  key_name   = "${var.name_prefix}-admin"
  public_key = file("${path.module}/../keys/gitops-admin.pub")

  tags = {
    Name = "${var.name_prefix}-admin"
  }
}

# resource "tls_private_key" "fleet" {
#   algorithm = "ED25519"
# }

# resource "aws_key_pair" "fleet" {
#   key_name   = "${var.name_prefix}-fleet"
#   public_key = tls_private_key.fleet.public_key_openssh

#   tags = {
#     Name = "${var.name_prefix}-fleet"
#   }
# }
