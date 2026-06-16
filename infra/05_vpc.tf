locals {
  az = "${var.region}a"
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.name_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.name_prefix}-igw"
  }
}

resource "aws_subnet" "dmz" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.10.0/24"
  availability_zone       = local.az
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name_prefix}-dmz"
    Tier = "dmz"
  }
}

resource "aws_subnet" "app" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.20.0/24"
  availability_zone       = local.az
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.name_prefix}-app"
    Tier = "app"
  }
}

resource "aws_subnet" "mgmt" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.99.0/24"
  availability_zone       = local.az
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name_prefix}-mgmt"
    Tier = "mgmt"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.name_prefix}-rt-public"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.name_prefix}-rt-private"
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
