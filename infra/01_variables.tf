# variables.tf

variable "admin_cidr" {
  description = "CIDR allowed to SSH into the jump host. Set to your workstation IP/32."
  type        = string
}
