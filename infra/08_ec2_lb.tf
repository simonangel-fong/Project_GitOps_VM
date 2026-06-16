# ec2_lb.tf

# ##############################
# SG
# ##############################
resource "aws_security_group" "lb" {
  name        = "${local.project_name}-sg-lb"
  description = "LB: HTTP from world, SSH from jump, all egress."
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${local.project_name}-sg-lb"
  }
}

resource "aws_vpc_security_group_ingress_rule" "lb_http_from_world" {
  security_group_id = aws_security_group.lb.id
  description       = "HTTP from the internet."
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "lb_ssh_from_jump" {
  security_group_id            = aws_security_group.lb.id
  description                  = "SSH from jump host SG only."
  referenced_security_group_id = aws_security_group.jump.id
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
}

resource "aws_vpc_security_group_egress_rule" "lb_egress_all" {
  security_group_id = aws_security_group.lb.id
  description       = "All egress."
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}


# ##############################
# EC2: LB
# ##############################
resource "aws_instance" "lb" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.dmz.id
  private_ip             = local.ec2_lb_cidr
  vpc_security_group_ids = [aws_security_group.lb.id]
  key_name               = aws_key_pair.fleet.key_name

  tags = {
    Name = "${local.project_name}-lb"
    Role = "lb"
  }
}

resource "aws_eip" "lb" {
  instance = aws_instance.lb.id
  domain   = "vpc"

  tags = {
    Name = "${local.project_name}-lb-eip"
  }
}
