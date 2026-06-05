resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Allow public HTTP traffic to ALB"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-ec2-sg"
  description = "Allow ALB to app port and admin CIDR to SSH/API"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${var.project_name}-ec2-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
  description       = "Public HTTP to ALB"
}

resource "aws_vpc_security_group_egress_rule" "alb_all" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "ALB egress to targets"
}

resource "aws_vpc_security_group_ingress_rule" "ec2_from_alb_nodeport" {
  security_group_id            = aws_security_group.ec2.id
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = var.node_port
  ip_protocol                  = "tcp"
  to_port                      = var.node_port
  description                  = "ALB to Kubernetes NodePort"
}

resource "aws_vpc_security_group_ingress_rule" "ec2_admin_ssh" {
  security_group_id = aws_security_group.ec2.id
  cidr_ipv4         = var.admin_cidr
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
  description       = "Admin SSH to fetch kubeconfig"
}

resource "aws_vpc_security_group_ingress_rule" "ec2_admin_kube_api" {
  security_group_id = aws_security_group.ec2.id
  cidr_ipv4         = var.admin_cidr
  from_port         = 6443
  ip_protocol       = "tcp"
  to_port           = 6443
  description       = "Admin access to kind Kubernetes API"
}

resource "aws_vpc_security_group_egress_rule" "ec2_all" {
  security_group_id = aws_security_group.ec2.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "EC2 egress for package and image downloads"
}

