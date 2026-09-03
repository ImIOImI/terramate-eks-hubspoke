# iam — reusable IAM policy documents (identical to the symbols-IAM spike).
# Each function returns a jsonencode()d policy; pure in, pure out.

values {
  policy_version = "2012-10-17"
}

# EKS Pod Identity service trust (ebs-csi, argocd controller).
function "pod_identity_trust" {
  return = jsonencode({
    Version = value.policy_version
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })
}

# Cross-account AWS-principal trust. principals: string|list; actions:
# "sts:AssumeRole" or ["sts:AssumeRole","sts:TagSession"] (passthrough keeps
# the original Action type).
function "aws_principal_trust" {
  parameter "principals" { type = any }
  parameter "actions" { type = any }
  return = jsonencode({
    Version = value.policy_version
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = param.principals }
      Action    = param.actions
    }]
  })
}

# Allow-sts:AssumeRole permission policy. resources: string|list.
function "assume_role_policy" {
  parameter "resources" { type = any }
  return = jsonencode({
    Version = value.policy_version
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
    Version = value.policy_version
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
