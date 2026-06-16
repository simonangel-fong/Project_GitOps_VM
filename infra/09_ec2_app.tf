# ec2_app.tf

# ##############################
# SG
# ##############################
resource "aws_security_group" "app" {
  name        = "${local.project_name}-sg-app"
  description = "App: 8080 from lb + jump, SSH from jump, egress VPC-only."
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${local.project_name}-sg-app"
  }
}

resource "aws_vpc_security_group_ingress_rule" "app_8080_from_lb" {
  security_group_id            = aws_security_group.app.id
  description                  = "App port from LB SG (prod traffic)."
  referenced_security_group_id = aws_security_group.lb.id
  ip_protocol                  = "tcp"
  from_port                    = 8080
  to_port                      = 8080
}

resource "aws_vpc_security_group_ingress_rule" "app_8080_from_jump" {
  security_group_id            = aws_security_group.app.id
  description                  = "App port from jump SG (deploy pipeline healthz curl)."
  referenced_security_group_id = aws_security_group.jump.id
  ip_protocol                  = "tcp"
  from_port                    = 8080
  to_port                      = 8080
}

resource "aws_vpc_security_group_ingress_rule" "app_ssh_from_jump" {
  security_group_id            = aws_security_group.app.id
  description                  = "SSH from jump SG only."
  referenced_security_group_id = aws_security_group.jump.id
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
}

resource "aws_vpc_security_group_egress_rule" "app_egress_vpc_only" {
  security_group_id = aws_security_group.app.id
  description       = "Egress restricted to VPC CIDR - app VMs cannot reach internet."
  cidr_ipv4         = aws_vpc.main.cidr_block
  ip_protocol       = "-1"
}


# ##############################
# EC2: App
# ##############################
resource "aws_instance" "app_vm1" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.app.id
  private_ip             = local.ec2_app_vm1_cidr
  vpc_security_group_ids = [aws_security_group.app.id]
  key_name               = aws_key_pair.fleet.key_name

  tags = {
    Name = "${local.project_name}-app-vm1"
    Role = "canary"
  }
}

resource "aws_instance" "app_vm2" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.app.id
  private_ip             = local.ec2_app_vm2_cidr
  vpc_security_group_ids = [aws_security_group.app.id]
  key_name               = aws_key_pair.fleet.key_name

  tags = {
    Name = "${local.project_name}-app-vm2"
    Role = "stable"
  }
}
