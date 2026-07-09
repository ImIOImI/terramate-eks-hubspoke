// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

resource "aws_iam_role" "spoke_access" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::111111111111:role/tmhs-argocd-controller"
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession",
        ]
      },
    ]
  })
  name = "tmhs-argocd-spoke-access"
}
resource "kubernetes_secret" "registration" {
  data = {
    name   = "tmhs-eks-dev"
    server = var.cluster_endpoint
    config = jsonencode({
      awsAuthConfig = {
        clusterName = "tmhs-eks-dev"
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
      env                              = "dev"
    }
    name      = "cluster-tmhs-eks-dev"
    namespace = "argocd"
  }
}
