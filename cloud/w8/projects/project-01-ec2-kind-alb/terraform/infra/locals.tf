locals {
  common_tags = {
    Project     = var.project_name
    Owner       = var.owner
    Environment = "lab"
    ManagedBy   = "terraform"
  }

  selected_azs = slice(data.aws_availability_zones.available.names, 0, length(var.public_subnet_cidrs))
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

