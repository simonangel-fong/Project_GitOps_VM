resource "aws_security_group" "jump" {
  name        = "${var.name_prefix}-jump"
  description = "Jump host: SSH from admin CIDR; all egress"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.name_prefix}-sg-jump"
  }
}

resource "aws_security_group" "lb" {
  name        = "${var.name_prefix}-lb"
  description = "LB: HTTP from internet; SSH from jump; all egress"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.name_prefix}-sg-lb"
  }
}

resource "aws_security_group" "app" {
  name        = "${var.name_prefix}-app"
  description = "App: 8080 from lb+jump; SSH from jump; egress restricted to VPC"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.name_prefix}-sg-app"
  }
}

# ---------- sg-jump ----------

resource "aws_vpc_security_group_ingress_rule" "jump_ssh_from_admin" {
  security_group_id = aws_security_group.jump.id
  description       = "SSH from workstation"
  cidr_ipv4         = var.admin_cidr
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "jump_egress_all" {
  security_group_id = aws_security_group.jump.id
  description       = "All egress"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ---------- sg-lb ----------

resource "aws_vpc_security_group_ingress_rule" "lb_http_from_world" {
  security_group_id = aws_security_group.lb.id
  description       = "HTTP from internet"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "lb_ssh_from_jump" {
  security_group_id            = aws_security_group.lb.id
  description                  = "SSH from jump"
  referenced_security_group_id = aws_security_group.jump.id
  from_port                    = 22
  to_port                      = 22
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "lb_egress_all" {
  security_group_id = aws_security_group.lb.id
  description       = "All egress"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ---------- sg-app ----------

resource "aws_vpc_security_group_ingress_rule" "app_8080_from_lb" {
  security_group_id            = aws_security_group.app.id
  description                  = "App port from LB"
  referenced_security_group_id = aws_security_group.lb.id
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "app_8080_from_jump" {
  security_group_id            = aws_security_group.app.id
  description                  = "App port from jump (healthz curl)"
  referenced_security_group_id = aws_security_group.jump.id
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "app_ssh_from_jump" {
  security_group_id            = aws_security_group.app.id
  description                  = "SSH from jump"
  referenced_security_group_id = aws_security_group.jump.id
  from_port                    = 22
  to_port                      = 22
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "app_egress_vpc_only" {
  security_group_id = aws_security_group.app.id
  description       = "Egress restricted to VPC CIDR"
  cidr_ipv4         = aws_vpc.main.cidr_block
  ip_protocol       = "-1"
}
