variable "aws_region" {
  type        = string
  description = "AWS region for the lab."
  default     = "ap-southeast-1"
}

variable "project_name" {
  type        = string
  description = "Name prefix for AWS resources."
  default     = "demo-kind-alb"
}

variable "owner" {
  type        = string
  description = "Owner tag value."
  default     = "student"
}

variable "admin_cidr" {
  type        = string
  description = "CIDR allowed to SSH and access the kind Kubernetes API. Use your public IP with /32."

  validation {
    condition     = var.admin_cidr != "0.0.0.0/0"
    error_message = "admin_cidr must not be 0.0.0.0/0."
  }
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR."
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "At least two public subnet CIDRs for ALB."
  default     = ["10.20.1.0/24", "10.20.2.0/24"]

  validation {
    condition     = length(var.public_subnet_cidrs) >= 2
    error_message = "ALB requires at least two public subnets."
  }
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type for the 3-node kind host. t3.small is Free Tier eligible in ap-southeast-1 for this lab account."
  default     = "t3.small"
}

variable "root_volume_size" {
  type        = number
  description = "Root volume size in GiB. Amazon Linux 2023 AMIs can require at least 30 GiB."
  default     = 30

  validation {
    condition     = var.root_volume_size >= 30
    error_message = "root_volume_size must be at least 30 GiB for the selected Amazon Linux 2023 AMI."
  }
}

variable "node_port" {
  type        = number
  description = "NodePort exposed by Kubernetes and targeted by ALB."
  default     = 30080

  validation {
    condition     = var.node_port >= 30000 && var.node_port <= 32767
    error_message = "node_port must be in the Kubernetes NodePort range 30000-32767."
  }
}

variable "cluster_name" {
  type        = string
  description = "kind cluster name."
  default     = "demo-kind"
}

variable "kind_version" {
  type        = string
  description = "kind CLI version."
  default     = "v0.29.0"
}

variable "kubectl_version" {
  type        = string
  description = "kubectl version."
  default     = "v1.33.1"
}

variable "kind_node_image" {
  type        = string
  description = "kind node image."
  default     = "kindest/node:v1.33.1"
}

variable "ssh_user" {
  type        = string
  description = "SSH user for the selected AMI."
  default     = "ec2-user"
}
