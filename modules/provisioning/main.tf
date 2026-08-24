language {
  experiments = [symbol_libraries]
}
symbols "iam" {
  source = "../../lib/iam"
}

terraform {
  required_version = ">= 1.11.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
    # kubernetes.hub targets the hub cluster (spoke registration secret).
    kubernetes = {
      source                = "hashicorp/kubernetes"
      version               = "~> 2.38"
      configuration_aliases = [kubernetes.hub]
    }
  }
}

variable "cluster_name" { type = string }
variable "env" { type = string }
variable "addon_versions" { type = map(string) }

# Hub ArgoCD controller role ARN that may assume this spoke's access role.
variable "controller_arn" { type = string }

# This spoke cluster's own endpoint + CA (base64), for the registration secret.
variable "cluster_endpoint" { type = string }
variable "cluster_ca" { type = string }

# ---- core add-ons (both roles) ----
resource "aws_eks_addon" "coredns" {
  cluster_name  = var.cluster_name
  addon_name    = "coredns"
  addon_version = var.addon_versions["coredns"]
}
resource "aws_iam_role" "ebs_csi" {
  name               = "tmhs-ebs-csi-${var.env}"
  assume_role_policy = symbols::iam::pod_identity_trust()
}
resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}
resource "aws_eks_pod_identity_association" "ebs_csi" {
  cluster_name    = var.cluster_name
  namespace       = "kube-system"
  service_account = "ebs-csi-controller-sa"
  role_arn        = aws_iam_role.ebs_csi.arn
}
resource "aws_eks_addon" "ebs_csi" {
  cluster_name  = var.cluster_name
  addon_name    = "aws-ebs-csi-driver"
  addon_version = var.addon_versions["aws-ebs-csi-driver"]
  depends_on    = [aws_eks_pod_identity_association.ebs_csi]
}

# ---- ArgoCD spoke registration ----
resource "aws_iam_role" "spoke_access" {
  name               = "tmhs-argocd-spoke-access"
  assume_role_policy = symbols::iam::aws_principal_trust(var.controller_arn, ["sts:AssumeRole", "sts:TagSession"])
}

resource "kubernetes_secret" "registration" {
  provider = kubernetes.hub

  metadata {
    name      = "cluster-${var.cluster_name}"
    namespace = "argocd"
    labels = {
      "argocd.argoproj.io/secret-type" = "cluster"
      "env"                            = var.env
    }
  }

  data = {
    name   = var.cluster_name
    server = var.cluster_endpoint
    config = jsonencode({
      awsAuthConfig = {
        clusterName = var.cluster_name
        roleARN     = aws_iam_role.spoke_access.arn
      }
      tlsClientConfig = { caData = var.cluster_ca }
    })
  }
}
