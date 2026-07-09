define "component" "metadata" {
  class       = "components/providers/kubernetes"
  version     = "0.1.0"
  name        = "kubernetes"
  description = "Kubernetes (and optionally Helm) provider using exec auth; greenfield-safe via outputs-sharing"
}

define "component" {
  # ── own cluster connection ──────────────────────────────────────────────────
  input "cluster_name" {
    type        = string
    description = "EKS cluster name; used in aws eks get-token --cluster-name. Deterministic, not shared."
  }
  input "env" {
    type        = string
    description = "target environment id; keys into account_map to resolve deploy_role_arn"
  }
  input "account_map" {
    type        = any
    description = "map of env -> account config object with region and deploy_role_arn keys"
  }
  input "cluster_stack_id" {
    type        = string
    description = "Terramate stack UUID of the own-env eks-cluster stack; used to wire endpoint+CA sharing inputs"
  }

  # ── optional helm provider ──────────────────────────────────────────────────
  input "include_helm" {
    type        = bool
    description = "when true, also emit a helm provider block (v3 attribute syntax) using the same exec auth"
    default     = false
  }

  # ── hub-aliased provider (spoke provisioning stacks only) ───────────────────
  input "hub_env" {
    type        = string
    description = "environment id of the hub cluster; empty string = no hub provider emitted"
    default     = ""
  }
  input "hub_cluster_name" {
    type        = string
    description = "hub EKS cluster name; used in aws eks get-token for hub alias"
    default     = ""
  }
  input "hub_cluster_stack_id" {
    type        = string
    description = "Terramate stack UUID of the hub eks-cluster stack; used to wire hub endpoint+CA sharing inputs"
    default     = ""
  }
}
