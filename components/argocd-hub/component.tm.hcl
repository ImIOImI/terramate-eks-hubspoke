define "component" "metadata" {
  class       = "components/argocd-hub"
  version     = "0.1.0"
  name        = "argocd-hub"
  description = "ArgoCD hub installation: controller IAM role (pod-identity), spoke-assume policy, Helm release, pod-identity associations for application-controller + server SAs"
}

define "component" {
  input "enabled" {
    type        = bool
    description = "when false, emit nothing (gates every generate block). Set by the eks-cluster bundle to role==\"hub\" — conditional components are not supported, so a disabled hub component is instantiated in spoke provisioning stacks but generates no HCL."
    default     = true
  }
  input "cluster_name" {
    type        = string
    description = "EKS cluster name"
  }
  input "env" {
    type        = string
    description = "target environment id"
  }
  input "account_map" {
    type        = any
    description = "map of env -> account config object (needs .account_id per spoke env)"
  }
  input "project_prefix" {
    type        = string
    description = "short name prefix used for all named resources"
  }
  input "argocd_chart_version" {
    type        = string
    description = "Helm chart version for argo-cd (from https://argoproj.github.io/argo-helm)"
  }
  input "spoke_envs" {
    type        = any
    description = "list of environment ids whose spoke-access roles the ArgoCD controller may assume"
  }
}
