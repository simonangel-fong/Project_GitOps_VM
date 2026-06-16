# ec2_jump.tf

# AMI
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# access key
data "aws_key_pair" "ansible" {
  key_name = "ansible"
}


# ##############################
# SG
# ##############################
resource "aws_security_group" "jump" {
  name        = "${local.project_name}-sg-jump"
  description = "Jump host: SSH from admin CIDR only, all egress."
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${local.project_name}-sg-jump"
  }
}

resource "aws_vpc_security_group_ingress_rule" "jump_ssh_from_admin" {
  security_group_id = aws_security_group.jump.id
  description       = "SSH from workstation admin CIDR."
  cidr_ipv4         = var.admin_cidr
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "jump_egress_all" {
  security_group_id = aws_security_group.jump.id
  description       = "All egress."
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}


# ##############################
# EC2: Jump
# ##############################
resource "aws_instance" "jump" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.mgmt.id
  private_ip             = local.ec2_jump_cidr
  vpc_security_group_ids = [aws_security_group.jump.id]
  key_name               = data.aws_key_pair.ansible.key_name

  tags = {
    Name = "${local.project_name}-jump"
    Role = "jump"
  }
}

resource "aws_eip" "jump" {
  instance = aws_instance.jump.id
  domain   = "vpc"

  tags = {
    Name = "${local.project_name}-jump-eip"
  }
}
