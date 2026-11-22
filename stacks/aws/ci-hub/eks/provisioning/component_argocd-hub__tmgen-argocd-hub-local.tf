// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 4.7"
    }
  }
}
resource "kubernetes_service_v1" "argocd_server_nodeport" {
  depends_on = [
    helm_release.argocd,
  ]
  metadata {
    name      = "argocd-server-local"
    namespace = "argocd"
  }
  spec {
    selector = {
      "app.kubernetes.io/name" = "argocd-server"
    }
    type = "NodePort"
    port {
      name        = "https"
      node_port   = 30443
      port        = 443
      target_port = 8080
    }
  }
}
resource "docker_image" "socat" {
  keep_locally = true
  name         = "alpine/socat:1.8.0.3"
}
resource "docker_container" "argocd_proxy" {
  command = [
    "tcp-listen:8443,fork,reuseaddr",
    "tcp:${trimspace(file("../../../../../.ministack/tmhs-eks-ci-hub.ip"))}:30443",
  ]
  depends_on = [
    kubernetes_service_v1.argocd_server_nodeport,
  ]
  image   = docker_image.socat.image_id
  name    = "ministack-argocd-tmhs-eks-ci-hub"
  restart = "unless-stopped"
  ports {
    external = 8443
    internal = 8443
    ip       = "127.0.0.1"
  }
}
data "kubernetes_secret_v1" "argocd_initial_admin" {
  depends_on = [
    helm_release.argocd,
  ]
  metadata {
    name      = "argocd-initial-admin-secret"
    namespace = "argocd"
  }
}
output "argocd_url" {
  description = "Hub ArgoCD UI (self-signed certificate)"
  value       = "https://localhost:8443"
}
output "argocd_admin_password" {
  description = "Initial password for the ArgoCD admin user"
  sensitive   = true
  value       = data.kubernetes_secret_v1.argocd_initial_admin.data.password
}
