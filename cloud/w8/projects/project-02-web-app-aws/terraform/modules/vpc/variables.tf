variable "project_name" {
  type        = string
  description = "Name prefix used for VPC resources."
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC."

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid CIDR block."
  }
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for public subnets."

  validation {
    condition     = length(var.public_subnet_cidrs) >= 2
    error_message = "Use at least two public subnets for high availability."
  }
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for private subnets."

  validation {
    condition     = length(var.private_subnet_cidrs) >= 2
    error_message = "Use at least two private subnets for RDS subnet groups."
  }
}

variable "availability_zone_names" {
  type        = list(string)
  description = "Availability zones used by the subnets."

  validation {
    condition     = length(var.availability_zone_names) >= 2
    error_message = "Provide at least two availability zones."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to all VPC resources."
  default     = {}
}
