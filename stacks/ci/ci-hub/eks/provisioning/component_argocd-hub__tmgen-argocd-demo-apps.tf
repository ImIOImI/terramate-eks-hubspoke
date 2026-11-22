// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

variable "demo_apps_revision" {
  default     = "main"
  description = "git revision of https://github.com/ImIOImI/terramate-eks-hubspoke.git that ArgoCD deploys charts/ from"
  type        = string
}
resource "helm_release" "argocd_demo_apps" {
  chart = "argocd-apps"
  depends_on = [
    helm_release.argocd,
  ]
  name       = "argocd-demo-apps"
  namespace  = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  values = [
    yamlencode({
      applicationsets = {
        argo-rollouts = {
          generators = [
            {
              clusters = {
                selector = {
                  matchExpressions = [
                    {
                      key      = "env"
                      operator = "Exists"
                    },
                  ]
                }
              }
            },
          ]
          template = {
            metadata = {
              name = "argo-rollouts-{{name}}"
            }
            spec = {
              project = "default"
              source = {
                repoURL        = "https://argoproj.github.io/argo-helm"
                chart          = "argo-rollouts"
                targetRevision = "2.43.12"
                helm = {
                  releaseName = "argo-rollouts"
                }
              }
              destination = {
                server    = "{{server}}"
                namespace = "argo-rollouts"
              }
              syncPolicy = {
                automated = {
                  prune    = true
                  selfHeal = true
                }
                retry = {
                  backoff = {
                    duration    = "10s"
                    factor      = 2
                    maxDuration = "3m"
                  }
                  limit = 10
                }
                syncOptions = [
                  "CreateNamespace=true",
                  "ServerSideApply=true",
                ]
              }
            }
          }
        }
        hello-world = {
          generators = [
            {
              clusters = {
                selector = {
                  matchExpressions = [
                    {
                      key      = "env"
                      operator = "Exists"
                    },
                  ]
                }
              }
            },
          ]
          template = {
            metadata = {
              name = "hello-world-{{name}}"
            }
            spec = {
              project = "default"
              source = {
                repoURL        = "https://github.com/ImIOImI/terramate-eks-hubspoke.git"
                targetRevision = var.demo_apps_revision
                path           = "charts/hello-world"
                helm = {
                  parameters = [
                    {
                      name  = "env"
                      value = "{{metadata.labels.env}}"
                    },
                  ]
                }
              }
              destination = {
                server    = "{{server}}"
                namespace = "hello-world"
              }
              syncPolicy = {
                automated = {
                  prune    = true
                  selfHeal = true
                }
                retry = {
                  backoff = {
                    duration    = "10s"
                    factor      = 2
                    maxDuration = "3m"
                  }
                  limit = 10
                }
                syncOptions = [
                  "CreateNamespace=true",
                ]
              }
            }
          }
        }
        hello-rollout = {
          generators = [
            {
              clusters = {
                selector = {
                  matchExpressions = [
                    {
                      key      = "env"
                      operator = "Exists"
                    },
                  ]
                }
              }
            },
          ]
          template = {
            metadata = {
              name = "hello-rollout-{{name}}"
            }
            spec = {
              project = "default"
              source = {
                repoURL        = "https://github.com/ImIOImI/terramate-eks-hubspoke.git"
                targetRevision = var.demo_apps_revision
                path           = "charts/hello-rollout"
                helm = {
                  parameters = [
                    {
                      name  = "env"
                      value = "{{metadata.labels.env}}"
                    },
                  ]
                }
              }
              destination = {
                server    = "{{server}}"
                namespace = "hello-rollout"
              }
              syncPolicy = {
                automated = {
                  prune    = true
                  selfHeal = true
                }
                retry = {
                  backoff = {
                    duration    = "10s"
                    factor      = 2
                    maxDuration = "3m"
                  }
                  limit = 10
                }
                syncOptions = [
                  "CreateNamespace=true",
                  "SkipDryRunOnMissingResource=true",
                ]
              }
            }
          }
        }
      }
    }),
  ]
  version = "2.0.8"
}
