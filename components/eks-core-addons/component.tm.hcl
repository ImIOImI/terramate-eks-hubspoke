define "component" "metadata" {
  class       = "components/eks-core-addons"
  version     = "0.1.0"
  name        = "eks-core-addons"
  description = "CoreDNS add-on + EBS CSI driver (IAM role, pod-identity association, add-on); used by hub AND spoke provisioning stacks"
}

define "component" {
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
    description = "map of env -> account config object (needs .account_id)"
  }
  input "project_prefix" {
    type        = string
    description = "short name prefix used for all named resources"
  }
  input "addon_versions" {
    type        = any
    description = "map of add-on name -> version string; expects keys coredns and aws-ebs-csi-driver"
  }
}
