terraform {
  required_version = ">= 1.11.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }
}

variable "cluster_name" { type = string }
variable "kubernetes_version" { type = string }
variable "use_latest_ami_release_version" {
  type    = bool
  default = true
}
variable "private_subnet_ids" { type = list(string) }
variable "cluster_service_cidr" { type = string }
variable "node_instance_types" { type = list(string) }
variable "node_scaling" {
  type = object({ min = number, max = number })
}
variable "addon_versions" { type = map(string) }

# CNI add-ons first (control-plane only), then nodes, then pod-identity.
resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = var.cluster_name
  addon_name                  = "kube-proxy"
  addon_version               = var.addon_versions["kube-proxy"]
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = var.cluster_name
  addon_name                  = "vpc-cni"
  addon_version               = var.addon_versions["vpc-cni"]
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

module "nodes" {
  source  = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"
  version = "~> 21.0"

  name         = "${var.cluster_name}-default"
  cluster_name = var.cluster_name

  kubernetes_version             = var.kubernetes_version
  use_latest_ami_release_version = var.use_latest_ami_release_version

  subnet_ids     = var.private_subnet_ids
  instance_types = var.node_instance_types
  min_size       = var.node_scaling.min
  max_size       = var.node_scaling.max
  desired_size   = var.node_scaling.min

  cluster_service_cidr = var.cluster_service_cidr

  depends_on = [aws_eks_addon.kube_proxy, aws_eks_addon.vpc_cni]
}

resource "aws_eks_addon" "pod_identity" {
  cluster_name  = var.cluster_name
  addon_name    = "eks-pod-identity-agent"
  addon_version = var.addon_versions["eks-pod-identity-agent"]
  depends_on    = [module.nodes]
}
