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

# --- hub helpers: give a spoke's env id, get its HUB's ARN -------------------
function "hub_deploy_role_arn" {
  parameter "id" { type = string }
  return = symbols::deploy_role_arn(symbols::config::hub_env(param.id))
}
function "hub_controller_arn" {
  parameter "id" { type = string }
  return = symbols::argocd_controller_arn(symbols::config::hub_env(param.id))
}
