output "alb_dns_name" {
  description = "ALB DNS name."
  value       = aws_lb.this.dns_name
}

output "alb_url" {
  description = "HTTP URL for the demo app."
  value       = "http://${aws_lb.this.dns_name}"
}

output "target_group_arn" {
  description = "ALB target group ARN used for target health evidence."
  value       = aws_lb_target_group.app.arn
}

output "instance_id" {
  description = "EC2 instance ID."
  value       = aws_instance.kind.id
}

output "instance_public_ip" {
  description = "EC2 public IP used by the kubeconfig."
  value       = aws_instance.kind.public_ip
}

output "kube_api_endpoint" {
  description = "kind Kubernetes API endpoint."
  value       = "https://${aws_instance.kind.public_ip}:6443"
}

output "node_port" {
  description = "Kubernetes NodePort targeted by ALB."
  value       = var.node_port
}

output "ssh_private_key_path" {
  description = "Local generated private key path. Do not commit this file."
  value       = local_sensitive_file.ssh_private_key.filename
}
