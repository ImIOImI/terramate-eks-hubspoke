// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

resource "aws_iam_role" "deploy" {
  assume_role_policy = symbols::iam::aws_principal_trust([
    "arn:aws:iam::111111111111:role/tmhs-gha-ci",
  ], "sts:AssumeRole")
  name = "tmhs-deploy"
}
