// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

resource "aws_iam_role" "spoke_access" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::000000000099:role/tmhs-argocd-controller"
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
    name   = "tmhs-eks-ci-prd"
    server = "https://${trimspace(file("../../../../../.ministack/tmhs-eks-ci-prd.ip"))}:6443"
    config = jsonencode({
      tlsClientConfig = {
        caData   = filebase64("../../../../../.ministack/tmhs-eks-ci-prd.ca")
        certData = filebase64("../../../../../.ministack/tmhs-eks-ci-prd.crt")
        keyData  = filebase64("../../../../../.ministack/tmhs-eks-ci-prd.key")
      }
    })
  }
  provider = kubernetes.hub
  metadata {
    labels = {
      "argocd.argoproj.io/secret-type" = "cluster"
      env                              = "ci-prd"
    }
    name      = "cluster-tmhs-eks-ci-prd"
    namespace = "argocd"
  }
}
