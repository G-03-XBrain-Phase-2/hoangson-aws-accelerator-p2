variable "kubeconfig_path" {
  type        = string
  description = "Path to the kubeconfig fetched from the EC2 kind host."
}

variable "namespace" {
  type        = string
  description = "Kubernetes namespace for the demo app."
  default     = "demo-local"
}

variable "app_name" {
  type        = string
  description = "Application name."
  default     = "demo-app"
}

variable "app_image" {
  type        = string
  description = "Small public image used for the demo app."
  default     = "nginx:1.27-alpine"
}

variable "student_name" {
  type        = string
  description = "Student name displayed on the demo web page."
  default     = "Nguyen Hoang Son"
}

variable "group_name" {
  type        = string
  description = "Group name displayed on the demo web page."
  default     = "CD03"
}

variable "replicas" {
  type        = number
  description = "Number of app replicas."
  default     = 2

  validation {
    condition     = var.replicas >= 2
    error_message = "replicas must be at least 2 for the load-balancing evidence lab."
  }
}

variable "node_port" {
  type        = number
  description = "NodePort exposed on the kind node and EC2 host."
  default     = 30080

  validation {
    condition     = var.node_port >= 30000 && var.node_port <= 32767
    error_message = "node_port must be in the Kubernetes NodePort range 30000-32767."
  }
}
