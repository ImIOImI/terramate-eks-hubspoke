define "component" "metadata" {
  class       = "components/eks-cluster"
  version     = "0.1.0"
  name        = "eks-cluster"
  description = "EKS control plane; deferred add-ons; access entries for deploy + optional argocd spoke"
}

define "component" {
  input "terraform_modules" {
    type        = any
    description = "map of module name -> {source, version}; expects .eks.source and .eks.version"
  }
  input "cluster_name" {
    type        = string
    description = "EKS cluster name"
  }
  input "env" {
    type        = string
    description = "target environment id"
  }
  input "role" {
    type        = string
    description = "cluster role: hub or spoke"
  }
  input "account_map" {
    type        = any
    description = "map of env -> account config object (needs .deploy_role_arn and .account_id)"
  }
  input "project_prefix" {
    type        = string
    description = "short name prefix; used to construct the argocd-spoke-access role ARN"
  }
  input "network_stack_id" {
    type        = string
    description = "UUID of this env's network stack; used to wire vpc_id + private_subnet_ids sharing inputs"
  }
}
