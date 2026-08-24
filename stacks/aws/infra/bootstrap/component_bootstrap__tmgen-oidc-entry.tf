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
  assume_role_policy = symbols::iam::github_oidc_trust(aws_iam_openid_connect_provider.github.arn, "ImIOImI/terramate-eks-hubspoke")
  name               = "tmhs-gha-ci"
}
resource "aws_iam_role_policy" "gha_ci_assume" {
  name   = "assume-deploy-roles"
  policy = symbols::iam::assume_role_policy("arn:aws:iam::*:role/tmhs-deploy")
  role   = aws_iam_role.gha_ci.id
}
