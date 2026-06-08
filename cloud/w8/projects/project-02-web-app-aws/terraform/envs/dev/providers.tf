terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

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

locals {
  common_tags = {
    Project     = var.project_name
    Owner       = var.owner
    Environment = var.environment
    ManagedBy   = "terraform"
  }

  subnet_az_count    = max(length(var.public_subnet_cidrs), length(var.private_subnet_cidrs))
  selected_azs       = slice(data.aws_availability_zones.available.names, 0, local.subnet_az_count)
  assets_bucket_name = coalesce(var.assets_bucket_name, lower("${var.project_name}-${var.environment}-assets-${data.aws_caller_identity.current.account_id}"))
}
