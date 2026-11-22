// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

variable "demo_apps_revision" {
  default     = "main"
  description = "git revision of https://github.com/ImIOImI/terramate-eks-hubspoke.git that ArgoCD deploys k8s/ from"
  type        = string
}
resource "helm_release" "argocd_root_app" {
  chart = "argocd-apps"
  depends_on = [
    helm_release.argocd,
  ]
  name       = "argocd-root-app"
  namespace  = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  values = [
    yamlencode({
      applications = {
        k8s-argo = {
          namespace = "argocd"
          project   = "default"
          source = {
            repoURL        = "https://github.com/ImIOImI/terramate-eks-hubspoke.git"
            targetRevision = var.demo_apps_revision
            path           = "k8s/argo"
            kustomize = {
              patches = [
                {
                  target = {
                    kind          = "ApplicationSet"
                    labelSelector = "tmhs.io/revision=root"
                  }
                  patch = jsonencode([
                    {
                      op    = "replace"
                      path  = "/spec/template/spec/source/targetRevision"
                      value = var.demo_apps_revision
                    },
                  ])
                },
              ]
            }
          }
          destination = {
            server    = "https://kubernetes.default.svc"
            namespace = "argocd"
          }
          syncPolicy = {
            automated = {
              prune    = true
              selfHeal = true
            }
          }
        }
      }
    }),
  ]
  version = "2.0.8"
}
