resource "kubernetes_namespace_v1" "app" {
  metadata {
    name = var.namespace

    labels = {
      name       = var.namespace
      managed_by = "terraform"
    }
  }
}

