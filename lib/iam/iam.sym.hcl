# OpenTofu Symbol Library: reusable IAM policy documents.
#
# Requires the `symbol_libraries` language experiment (OpenTofu >= 1.13.0-dev,
# symbol_libraries landed on main 2026-08-24). Consuming stacks emit:
#   language { experiments = [symbol_libraries] }
#   symbols "iam" { source = "<relpath>/lib/iam" }
# and call e.g. symbols::iam::pod_identity_trust().
#
# Each function returns a jsonencode()d IAM policy document identical to the
# inline jsonencode blocks it replaces — same values through the same encoder,
# so tofu plan is a no-op.

# Single source of truth for the IAM policy language version.
function "policy_version" {
  return = "2012-10-17"
}

# EKS Pod Identity service trust. Same document for every pod-identity role
# (ebs-csi controller, argocd controller). TagSession is required: EKS Pod
# Identity always includes it in the assume-role call.
function "pod_identity_trust" {
  return = jsonencode({
    Version = symbols::policy_version()
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })
}

# Cross-account AWS-principal trust. `principals` takes a string or list;
# `actions` takes "sts:AssumeRole" (plain) or ["sts:AssumeRole","sts:TagSession"]
# (when the principal uses pod identity). Passing actions through verbatim keeps
# the rendered Action type identical to the inline original.
function "aws_principal_trust" {
  parameter "principals" { type = any }
  parameter "actions" { type = any }
  return = jsonencode({
    Version = symbols::policy_version()
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = param.principals }
      Action    = param.actions
    }]
  })
}

# Allow-sts:AssumeRole permission policy. `resources` takes a string or list.
function "assume_role_policy" {
  parameter "resources" { type = any }
  return = jsonencode({
    Version = symbols::policy_version()
    Statement = [{
      Effect   = "Allow"
      Action   = "sts:AssumeRole"
      Resource = param.resources
    }]
  })
}

# GitHub Actions OIDC web-identity trust, scoped to one repo.
function "github_oidc_trust" {
  parameter "provider_arn" { type = string }
  parameter "repo" { type = string }
  return = jsonencode({
    Version = symbols::policy_version()
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = param.provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = { "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com" }
        StringLike   = { "token.actions.githubusercontent.com:sub" = "repo:${param.repo}:*" }
      }
    }]
  })
}
