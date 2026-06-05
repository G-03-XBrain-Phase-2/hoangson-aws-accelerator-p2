resource "kubernetes_deployment_v1" "app" {
  metadata {
    name      = var.app_name
    namespace = kubernetes_namespace_v1.app.metadata[0].name
    labels    = local.labels
  }

  spec {
    replicas = var.replicas

    strategy {
      type = "RollingUpdate"

      rolling_update {
        max_surge       = "0"
        max_unavailable = "1"
      }
    }

    selector {
      match_labels = local.labels
    }

    template {
      metadata {
        labels = local.labels
      }

      spec {
        topology_spread_constraint {
          max_skew           = 1
          topology_key       = "kubernetes.io/hostname"
          when_unsatisfiable = "DoNotSchedule"

          label_selector {
            match_labels = local.labels
          }
        }

        container {
          name  = "app"
          image = var.app_image

          port {
            name           = "http"
            container_port = 80
          }

          readiness_probe {
            http_get {
              path = "/healthz"
              port = 80
            }

            initial_delay_seconds = 5
            period_seconds        = 5
            timeout_seconds       = 2
            failure_threshold     = 3
          }

          liveness_probe {
            http_get {
              path = "/healthz"
              port = 80
            }

            initial_delay_seconds = 15
            period_seconds        = 10
            timeout_seconds       = 2
            failure_threshold     = 3
          }

          resources {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }

            limits = {
              cpu    = "250m"
              memory = "128Mi"
            }
          }

          volume_mount {
            name       = "content"
            mount_path = "/usr/share/nginx/html"
            read_only  = true
          }
        }

        volume {
          name = "content"

          config_map {
            name = kubernetes_config_map_v1.app.metadata[0].name

            items {
              key  = "index.html"
              path = "index.html"
            }

            items {
              key  = "healthz"
              path = "healthz"
            }
          }
        }
      }
    }
  }
}
