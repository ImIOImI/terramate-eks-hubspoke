// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

resource "aws_eks_addon" "kube_proxy" {
  addon_name    = "kube-proxy"
  addon_version = "v1.33.10-eksbuild.13"
  cluster_name  = "tmhs-eks-infra"
}
resource "aws_eks_addon" "vpc_cni" {
  addon_name    = "vpc-cni"
  addon_version = "v1.22.2-eksbuild.1"
  cluster_name  = "tmhs-eks-infra"
}
module "nodes" {
  cluster_name         = "tmhs-eks-infra"
  cluster_service_cidr = var.cluster_service_cidr
  depends_on = [
    aws_eks_addon.kube_proxy,
    aws_eks_addon.vpc_cni,
  ]
  desired_size = 2
  instance_types = [
    "t3.large",
  ]
  max_size   = 3
  min_size   = 2
  name       = "tmhs-eks-infra-default"
  source     = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"
  subnet_ids = var.private_subnet_ids
  version    = "21.24.0"
}
resource "aws_eks_addon" "pod_identity" {
  addon_name    = "eks-pod-identity-agent"
  addon_version = "v1.3.8-eksbuild.2"
  cluster_name  = "tmhs-eks-infra"
  depends_on = [
    module.nodes,
  ]
}
