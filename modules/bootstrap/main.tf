terraform {
  required_version = ">= 1.11.0"
}
language {
  experiments = [symbol_libraries]
}
symbols "iam" {
  source = "../../lib/iam"
}

variable "project_prefix" { type = string }
variable "state_bucket" { type = string }
variable "lock_table" { type = string }

# Static trust for the deploy role: the OIDC-entry account's gha-ci ARN plus any
# extra admin principals. The current caller is added dynamically below.
variable "static_trust" { type = list(string) }

variable "github_repo" { type = string }
variable "oidc_entry" {
  type    = bool
  default = false
}

resource "aws_s3_bucket" "state" {
  bucket = var.state_bucket
}
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "aws:kms" }
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
  name         = var.lock_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
}

data "aws_caller_identity" "current" {}

locals {
  caller_arn      = data.aws_caller_identity.current.arn
  caller_assumed  = can(regex("^arn:aws:sts::[0-9]+:assumed-role/", local.caller_arn))
  caller_sso      = can(regex(":assumed-role/AWSReservedSSO_", local.caller_arn))
  caller_role_arn = local.caller_assumed ? replace(local.caller_arn, "/^arn:aws:sts::([0-9]+):assumed-role/([^/]+)/.*/", "arn:aws:iam::$1:role/$2") : local.caller_arn
  caller_trust    = local.caller_sso ? [] : [local.caller_role_arn]
  deploy_trust    = distinct(concat(var.static_trust, local.caller_trust))
}

resource "aws_iam_role" "deploy" {
  name               = "${var.project_prefix}-deploy"
  assume_role_policy = symbols::iam::aws_principal_trust(local.deploy_trust, "sts:AssumeRole")
}
resource "aws_iam_role_policy_attachment" "deploy_admin" {
  role       = aws_iam_role.deploy.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# GitHub OIDC provider + gha-ci entry role — only in the oidc_entry account.
data "tls_certificate" "github" {
  count = var.oidc_entry ? 1 : 0
  url   = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}
resource "aws_iam_openid_connect_provider" "github" {
  count           = var.oidc_entry ? 1 : 0
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github[0].certificates[0].sha1_fingerprint]
}
resource "aws_iam_role" "gha_ci" {
  count              = var.oidc_entry ? 1 : 0
  name               = "${var.project_prefix}-gha-ci"
  assume_role_policy = symbols::iam::github_oidc_trust(aws_iam_openid_connect_provider.github[0].arn, var.github_repo)
}
resource "aws_iam_role_policy" "gha_ci_assume" {
  count  = var.oidc_entry ? 1 : 0
  name   = "assume-deploy-roles"
  role   = aws_iam_role.gha_ci[0].id
  policy = symbols::iam::assume_role_policy("arn:aws:iam::*:role/${var.project_prefix}-deploy")
}
