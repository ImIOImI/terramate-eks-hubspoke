define "component" "metadata" {
  class       = "components/bootstrap"
  version     = "0.1.0"
  name        = "bootstrap"
  description = "State bucket, lock table, deploy role; optionally GitHub OIDC CI entry"
}

define "component" {
  input "project_prefix" {
    type        = string
    description = "short name prefix used for all named resources"
  }
  input "env" {
    type        = string
    description = "target environment id"
  }
  input "account_map" {
    type        = any
    description = "map of env -> account config object"
  }
  input "github_repo" {
    type        = string
    description = "GitHub repo slug (owner/repo) for OIDC trust condition"
  }
  input "ci_env" {
    type        = string
    description = "environment id of the account holding the gha-ci entry role that every deploy role trusts"
    default     = "infra"
  }
  input "ci_entry" {
    type        = bool
    description = "Create the GitHub OIDC provider + gha-ci entry role in this account"
    default     = false
  }
  input "admin_principal_arns" {
    type        = any
    description = "IAM principal ARNs (users/roles) allowed to assume the deploy role"
    default     = []
  }
}
