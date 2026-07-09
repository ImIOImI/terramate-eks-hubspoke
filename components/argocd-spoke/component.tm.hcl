define "component" "metadata" {
  class       = "components/argocd-spoke"
  version     = "0.1.0"
  name        = "argocd-spoke"
  description = "ArgoCD spoke registration: IAM role for hub controller cross-account assume, and ArgoCD cluster secret written into the hub via kubernetes.hub provider"
}

define "component" {
  input "cluster_name" {
    type        = string
    description = "EKS cluster name of this spoke cluster"
  }
  input "env" {
    type        = string
    description = "target environment id for this spoke"
  }
  input "hub_env" {
    type        = string
    description = "environment id of the hub cluster; used to look up hub account_id for trust policy"
  }
  input "account_map" {
    type        = any
    description = "map of env -> account config object (needs .account_id per env)"
  }
  input "project_prefix" {
    type        = string
    description = "short name prefix used for all named resources"
  }
  input "cluster_stack_id" {
    type        = string
    description = "Terramate stack UUID of this spoke's eks-cluster stack; used by the kubernetes provider component to wire cluster_endpoint/cluster_ca sharing inputs"
  }
}
