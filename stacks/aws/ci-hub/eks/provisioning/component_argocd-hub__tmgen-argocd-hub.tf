// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

resource "aws_iam_role" "argocd_controller" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession",
        ]
      },
    ]
  })
  name = "tmhs-argocd-controller"
}
resource "aws_iam_role_policy" "argocd_assume_spokes" {
  name = "assume-spoke-access"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Resource = [
          "arn:aws:iam::222222222222:role/tmhs-argocd-spoke-access",
          "arn:aws:iam::333333333333:role/tmhs-argocd-spoke-access",
        ]
      },
    ]
  })
  role = aws_iam_role.argocd_controller.id
}
resource "helm_release" "argocd" {
  chart            = "argo-cd"
  create_namespace = true
  depends_on = [
    aws_eks_addon.coredns,
  ]
  name       = "argocd"
  namespace  = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  version    = "10.1.2"
}
