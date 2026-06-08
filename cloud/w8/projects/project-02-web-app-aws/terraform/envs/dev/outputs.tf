output "web_url" {
  description = "HTTP URL for the EC2 web server."
  value       = "http://${aws_instance.web.public_dns}"
}

output "web_public_ip" {
  description = "Public IP of the EC2 web server."
  value       = aws_instance.web.public_ip
}

output "vpc_id" {
  description = "VPC ID."
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs."
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs."
  value       = module.vpc.private_subnet_ids
}

output "rds_endpoint" {
  description = "RDS MySQL endpoint."
  value       = aws_db_instance.mysql.endpoint
}

output "rds_master_secret_arn" {
  description = "Secrets Manager secret ARN for the managed RDS master password."
  value       = try(aws_db_instance.mysql.master_user_secret[0].secret_arn, null)
  sensitive   = true
}

output "assets_bucket_name" {
  description = "Private S3 bucket for static assets."
  value       = aws_s3_bucket.assets.bucket
}
