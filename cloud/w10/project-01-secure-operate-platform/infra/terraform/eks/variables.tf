variable "aws_region" {
  description = "AWS region used for the W10 EKS cluster."
  type        = string
  default     = "ap-southeast-1"
}

variable "cluster_name" {
  description = "Name of the W10 EKS cluster."
  type        = string
  default     = "w10-secure-platform"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster."
  type        = string
  default     = "1.30"
}

variable "vpc_cidr" {
  description = "CIDR range for the dedicated W10 VPC."
  type        = string
  default     = "10.40.0.0/16"
}

variable "availability_zone_count" {
  description = "Number of availability zones used by the VPC."
  type        = number
  default     = 2
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDR blocks allowed to access the public EKS API endpoint. Replace 0.0.0.0/0 with your public IP /32 for stricter security."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "node_instance_types" {
  description = "EC2 instance types for the default managed node group."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_min_size" {
  description = "Minimum number of worker nodes."
  type        = number
  default     = 1
}

variable "node_desired_size" {
  description = "Desired number of worker nodes."
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum number of worker nodes."
  type        = number
  default     = 3
}

variable "external_secrets_namespace" {
  description = "Namespace where External Secrets Operator runs."
  type        = string
  default     = "external-secrets"
}

variable "external_secrets_service_account_name" {
  description = "Service account used by External Secrets Operator."
  type        = string
  default     = "external-secrets"
}

variable "external_secrets_role_name" {
  description = "IAM role name assumed by External Secrets Operator through IRSA."
  type        = string
  default     = "w10-external-secrets"
}

variable "external_secrets_allowed_secret_arns" {
  description = "Secrets Manager ARNs that ESO is allowed to read."
  type        = list(string)
  default = [
    "arn:aws:secretsmanager:ap-southeast-1:*:secret:prod/db/password-*",
    "arn:aws:secretsmanager:ap-southeast-1:*:secret:prod/alertmanager/smtp-password-*"
  ]
}

variable "tags" {
  description = "Common tags for W10 AWS resources."
  type        = map(string)
  default = {
    Project   = "w10-secure-operate-platform"
    ManagedBy = "terraform"
    Owner     = "phase2-cloud"
  }
}
