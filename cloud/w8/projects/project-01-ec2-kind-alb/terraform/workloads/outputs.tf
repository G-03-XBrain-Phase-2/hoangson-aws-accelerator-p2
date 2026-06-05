output "namespace" {
  description = "Namespace created by the Kubernetes provider."
  value       = kubernetes_namespace_v1.app.metadata[0].name
}

output "deployment_name" {
  description = "Deployment name."
  value       = kubernetes_deployment_v1.app.metadata[0].name
}

output "service_name" {
  description = "Service name."
  value       = kubernetes_service_v1.app.metadata[0].name
}

output "node_port" {
  description = "NodePort exposed by the service."
  value       = kubernetes_service_v1.app.spec[0].port[0].node_port
}

