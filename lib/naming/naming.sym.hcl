# naming — IAM role ARN builders (was scattered Terramate `lets`).
# References the config library for account ids + prefix.

symbols "config" {
  source = "../config"
}

function "deploy_role_arn" {
  parameter "env" { type = string }
  return = "arn:aws:iam::${symbols::config::account_id(param.env)}:role/${symbols::config::project_prefix()}-deploy"
}
function "gha_ci_arn" {
  parameter "env" { type = string }
  return = "arn:aws:iam::${symbols::config::account_id(param.env)}:role/${symbols::config::project_prefix()}-gha-ci"
}
function "argocd_controller_arn" {
  parameter "env" { type = string }
  return = "arn:aws:iam::${symbols::config::account_id(param.env)}:role/${symbols::config::project_prefix()}-argocd-controller"
}
function "spoke_access_arn" {
  parameter "env" { type = string }
  return = "arn:aws:iam::${symbols::config::account_id(param.env)}:role/${symbols::config::project_prefix()}-argocd-spoke-access"
}
