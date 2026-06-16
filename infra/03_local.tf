locals {
  aws_region      = "ca-central-1"
  project_name    = "gitops-vm"
  subnet_vpc_cidr = "10.0.0.0/16"

  # DMZ subnet
  subnet_dmz_cidr = "10.0.10.0/24"
  ec2_lb_cidr     = "10.0.10.20"

  # App subnet
  subnet_app_cidr = "10.0.20.0/24"

  # mgmt subnet
  subnet_mgmt_cidr = "10.0.90.0/24"
  ec2_jump_cidr    = "10.0.90.10"
}
