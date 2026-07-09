generate_hcl "_tmgen-bootstrap.tf" {
  lets {
    acct   = component.input.account_map.value[component.input.env.value]
    prefix = component.input.project_prefix.value
    # Construct gha-ci ARN from the infra account (cross-account deploy trust)
    gha_ci_arn = "arn:aws:iam::${component.input.account_map.value["infra"].account_id}:role/${component.input.project_prefix.value}-gha-ci"
    # Merge gha-ci ARN with any extra admin principals
    trust_principals = tm_concat(
      [let.gha_ci_arn],
      component.input.admin_principal_arns.value
    )
  }
  content {
    resource "aws_s3_bucket" "state" {
      bucket = let.acct.state_bucket
    }
    resource "aws_s3_bucket_versioning" "state" {
      bucket = aws_s3_bucket.state.id
      versioning_configuration {
        status = "Enabled"
      }
    }
    resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
      bucket = aws_s3_bucket.state.id
      rule {
        apply_server_side_encryption_by_default {
          sse_algorithm = "aws:kms"
        }
        bucket_key_enabled = true
      }
    }
    resource "aws_s3_bucket_public_access_block" "state" {
      bucket                  = aws_s3_bucket.state.id
      block_public_acls       = true
      block_public_policy     = true
      ignore_public_acls      = true
      restrict_public_buckets = true
    }
    resource "aws_dynamodb_table" "locks" {
      name         = let.acct.lock_table
      billing_mode = "PAY_PER_REQUEST"
      hash_key     = "LockID"
      attribute {
        name = "LockID"
        type = "S"
      }
    }
    resource "aws_iam_role" "deploy" {
      name = "${let.prefix}-deploy"
      assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Effect    = "Allow"
          Principal = { AWS = let.trust_principals }
          Action    = "sts:AssumeRole"
        }]
      })
    }
    resource "aws_iam_role_policy_attachment" "deploy_admin" {
      role       = aws_iam_role.deploy.name
      policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
    }
  }
}

generate_hcl "_tmgen-ci-entry.tf" {
  condition = component.input.ci_entry.value
  lets {
    prefix = component.input.project_prefix.value
  }
  content {
    data "tls_certificate" "github" {
      url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
    }
    resource "aws_iam_openid_connect_provider" "github" {
      url             = "https://token.actions.githubusercontent.com"
      client_id_list  = ["sts.amazonaws.com"]
      thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
    }
    resource "aws_iam_role" "gha_ci" {
      name = "${let.prefix}-gha-ci"
      assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Effect    = "Allow"
          Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
          Action    = "sts:AssumeRoleWithWebIdentity"
          Condition = {
            StringEquals = { "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com" }
            StringLike   = { "token.actions.githubusercontent.com:sub" = "repo:${component.input.github_repo.value}:*" }
          }
        }]
      })
    }
    resource "aws_iam_role_policy" "gha_ci_assume" {
      name = "assume-deploy-roles"
      role = aws_iam_role.gha_ci.id
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Effect   = "Allow"
          Action   = "sts:AssumeRole"
          Resource = "arn:aws:iam::*:role/${let.prefix}-deploy"
        }]
      })
    }
  }
}
