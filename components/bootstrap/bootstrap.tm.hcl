# State backend + deploy-role foundation. The bucket/lock/admin-attachment are
# endpoint-agnostic and live here; the deploy role's trust differs real-vs-local,
# so it is emitted by the two opposite-condition blocks below (keeping real-AWS
# and MiniStack output cleanly separated, per the repo's codegen convention).
generate_hcl "_tmgen-bootstrap.tf" {
  lets {
    acct = component.input.account_map.value[component.input.env.value]
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
    resource "aws_iam_role_policy_attachment" "deploy_admin" {
      role       = aws_iam_role.deploy.name
      policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
    }
  }
}

# ---------------------------------------------------------------------------
# Deploy role — REAL AWS. Trust = gha-ci + any admin_principal_arns + the
# auto-derived *caller* (via data.aws_caller_identity), so whoever runs
# `make apply ENV=<id>` can assume the role the eks tiers need, in the same run.
# A propagation gate then holds this stack open until STS will honor the assume,
# so the `after`-ordered network tier never races IAM eventual consistency.
# ---------------------------------------------------------------------------
generate_hcl "_tmgen-deploy-role.tf" {
  condition = component.input.account_map.value[component.input.env.value].endpoint == ""
  lets {
    prefix     = component.input.project_prefix.value
    gha_ci_arn = "arn:aws:iam::${component.input.account_map.value[component.input.oidc_entry_env.value].account_id}:role/${component.input.project_prefix.value}-gha-ci"
    static_trust = tm_concat(
      [let.gha_ci_arn],
      component.input.admin_principal_arns.value,
    )
  }
  content {
    data "aws_caller_identity" "current" {}

    locals {
      # Normalize an assumed-role session ARN (arn:aws:sts::A:assumed-role/R/S) to
      # its IAM role ARN (arn:aws:iam::A:role/R); leave user/role ARNs untouched.
      caller_arn      = data.aws_caller_identity.current.arn
      caller_assumed  = can(regex("^arn:aws:sts::[0-9]+:assumed-role/", local.caller_arn))
      caller_sso      = can(regex(":assumed-role/AWSReservedSSO_", local.caller_arn))
      caller_role_arn = local.caller_assumed ? replace(local.caller_arn, "/^arn:aws:sts::([0-9]+):assumed-role/([^/]+)/.*/", "arn:aws:iam::$1:role/$2") : local.caller_arn
      # SSO reserved roles cannot be reconstructed from the STS ARN — those callers
      # trust themselves via admin_principal_arns instead.
      caller_trust = local.caller_sso ? [] : [local.caller_role_arn]
      deploy_trust = distinct(concat(let.static_trust, local.caller_trust))
    }

    resource "aws_iam_role" "deploy" {
      name = "${let.prefix}-deploy"
      assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Effect    = "Allow"
          Principal = { AWS = local.deploy_trust }
          Action    = "sts:AssumeRole"
        }]
      })
    }

    # IAM propagation gate: poll sts:AssumeRole (the exact op the next tier does)
    # from ambient creds until it succeeds, so this stack only completes once the
    # role is actually assumable. Everything downstream depends on the bootstrap
    # STACK (terramate `after`), so it inherits the gate. Requires the AWS CLI.
    resource "terraform_data" "deploy_role_ready" {
      triggers_replace = [aws_iam_role.deploy.arn]
      depends_on       = [aws_iam_role.deploy, aws_iam_role_policy_attachment.deploy_admin]
      provisioner "local-exec" {
        interpreter = ["/bin/bash", "-c"]
        environment = { ROLE_ARN = self.triggers_replace[0] }
        command     = <<-EOT
          for i in $(seq 1 30); do
            aws sts assume-role --role-arn "$ROLE_ARN" --role-session-name bootstrap-gate >/dev/null 2>&1 && exit 0
            echo "deploy role $ROLE_ARN not yet assumable, retry $i/30..." >&2
            sleep 10
          done
          echo "deploy role $ROLE_ARN never became assumable after 5m" >&2
          exit 1
        EOT
      }
    }
  }
}

# ---------------------------------------------------------------------------
# Deploy role — LOCAL (MiniStack). Static trust only (gha-ci + admin_principal_arns);
# no caller-identity data source and no propagation gate: MiniStack applies use the
# access key, never role assumption, so there is nothing to wait for. Kept byte-for-byte
# as the pre-existing behavior.
# ---------------------------------------------------------------------------
generate_hcl "_tmgen-deploy-role.tf" {
  condition = component.input.account_map.value[component.input.env.value].endpoint != ""
  lets {
    prefix     = component.input.project_prefix.value
    gha_ci_arn = "arn:aws:iam::${component.input.account_map.value[component.input.oidc_entry_env.value].account_id}:role/${component.input.project_prefix.value}-gha-ci"
    trust_principals = tm_concat(
      [let.gha_ci_arn],
      component.input.admin_principal_arns.value,
    )
  }
  content {
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
  }
}

# GitHub OIDC provider + gha-ci entry role — only in the oidc_entry account.
generate_hcl "_tmgen-oidc-entry.tf" {
  condition = component.input.oidc_entry.value
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
