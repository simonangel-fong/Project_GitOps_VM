variable "region" {
  description = "AWS region for all resources."
  type        = string
  default     = "ca-central-1"
}

variable "aws_profile" {
  description = "Named AWS CLI profile used by the provider."
  type        = string
  default     = "gitops-vm"
}

variable "name_prefix" {
  description = "Prefix applied to resource Name tags."
  type        = string
  default     = "gitops-vm"
}

variable "admin_cidr" {
  description = "CIDR allowed to SSH into the jump host. Set to your workstation IP/32."
  type        = string
}
