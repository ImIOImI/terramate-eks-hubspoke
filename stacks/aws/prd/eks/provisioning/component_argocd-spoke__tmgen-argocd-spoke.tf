// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

resource "aws_iam_role" "spoke_access" {
  assume_role_policy = symbols::iam::aws_principal_trust("arn:aws:iam::111111111111:role/tmhs-argocd-controller", [
    "sts:AssumeRole",
    "sts:TagSession",
  ])
  name = "tmhs-argocd-spoke-access"
}
resource "kubernetes_secret" "registration" {
  data = {
    name   = "tmhs-eks-prd"
    server = var.cluster_endpoint
    config = jsonencode({
      awsAuthConfig = {
        clusterName = "tmhs-eks-prd"
        roleARN     = aws_iam_role.spoke_access.arn
      }
      tlsClientConfig = {
        caData = var.cluster_ca
      }
    })
  }
  provider = kubernetes.hub
  metadata {
    labels = {
      "argocd.argoproj.io/secret-type" = "cluster"
      env                              = "prd"
    }
    name      = "cluster-tmhs-eks-prd"
    namespace = "argocd"
  }
}
