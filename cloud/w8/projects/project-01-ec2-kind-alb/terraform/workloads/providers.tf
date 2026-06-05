terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38"
    }
  }
}

provider "kubernetes" {
  config_path = var.kubeconfig_path
}

locals {
  labels = {
    app        = var.app_name
    managed_by = "terraform"
  }
}
