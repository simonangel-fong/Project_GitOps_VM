# vpc.tf
locals {
  az = "${local.aws_region}a"
}

# ##############################
# VPC
# ##############################
resource "aws_vpc" "main" {
  cidr_block           = local.subnet_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.project_name}"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.project_name}"
  }
}

# ##############################
# Subnet: DMZ
# ##############################
resource "aws_subnet" "dmz" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.subnet_dmz_cidr
  availability_zone       = local.az
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.project_name}-dmz"
    Tier = "dmz"
  }
}

# ##############################
# Subnet: app
# ##############################
resource "aws_subnet" "app" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.subnet_app_cidr
  availability_zone       = local.az
  map_public_ip_on_launch = false

  tags = {
    Name = "${local.project_name}-app"
    Tier = "app"
  }
}

# ##############################
# Subnet: mgmt
# ##############################
resource "aws_subnet" "mgmt" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.subnet_mgmt_cidr
  availability_zone       = local.az
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.project_name}-mgmt"
    Tier = "mgmt"
  }
}

# ##############################
# Subnet: public router
# ##############################
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${local.project_name}-rt-public"
  }
}

# ##############################
# Subnet: private router
# ##############################
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.project_name}-rt-private"
  }
}

resource "aws_route_table_association" "dmz" {
  subnet_id      = aws_subnet.dmz.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "mgmt" {
  subnet_id      = aws_subnet.mgmt.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "app" {
  subnet_id      = aws_subnet.app.id
  route_table_id = aws_route_table.private.id
}
