resource "kubernetes_deployment" "example" {
  metadata {
    name = var.name_prefix
    labels = {
      app = var.name_prefix
    }
  }

  spec {
    replicas = 3
    selector {
      match_labels = {
        app = var.name_prefix
      }
    }
    template {
      metadata {
        labels = {
          app = var.name_prefix
        }
      }

      spec {
        container {
          image = "shathacodes.azurecr.io/bookshopfront:cloud"
          name  = var.name_prefix

          port {
            container_port = 9000
          }
          env {
            name = "BACKEND_PREFIX_URL"
            value = "http://${var.back_ip}:8080"
          }

          resources {
            limits = {
              cpu    = "0.2"
              memory = "500Mi"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "test" {
  metadata {
    name      = "${var.name_prefix}-service"
    annotations = {
      "service.beta.kubernetes.io/azure-dns-label-name": "bookshop"
    }
        
  }
  spec {
    selector = {
      app = var.name_prefix
    }
    type = "LoadBalancer"
    port {
      port        = 9000
      target_port = 9000
    }
  }
}