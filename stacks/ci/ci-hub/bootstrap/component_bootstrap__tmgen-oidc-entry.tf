// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}
resource "aws_iam_openid_connect_provider" "github" {
  client_id_list = [
    "sts.amazonaws.com",
  ]
  thumbprint_list = [
    data.tls_certificate.github.certificates[0].sha1_fingerprint,
  ]
  url = "https://token.actions.githubusercontent.com"
}
resource "aws_iam_role" "gha_ci" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:ImIOImI/terramate-eks-hubspoke:*"
          }
        }
      },
    ]
  })
  name = "tmhs-gha-ci"
}
resource "aws_iam_role_policy" "gha_ci_assume" {
  name = "assume-deploy-roles"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = "arn:aws:iam::*:role/tmhs-deploy"
      },
    ]
  })
  role = aws_iam_role.gha_ci.id
}
