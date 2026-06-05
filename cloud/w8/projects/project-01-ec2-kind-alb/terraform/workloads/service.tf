resource "kubernetes_service_v1" "app" {
  metadata {
    name      = var.app_name
    namespace = kubernetes_namespace_v1.app.metadata[0].name
    labels    = local.labels
  }

  spec {
    type     = "NodePort"
    selector = local.labels

    port {
      name        = "http"
      protocol    = "TCP"
      port        = 80
      target_port = 80
      node_port   = var.node_port
    }
  }
}

