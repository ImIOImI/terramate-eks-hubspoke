define "bundle" "metadata" {
  class       = "account-bootstrap"
  version     = "0.1.0"
  name        = "Account Bootstrap"
  description = "State bucket, lock table, deploy role, and (infra only) GitHub OIDC CI entry"
}

# SPIKE A.2: bundle must opt in to environments or the YAML environments: key errors
define "bundle" "environments" {
  required = true
}

define "bundle" {
  # Disambiguates per-env instances in terramate output (e.g., bootstrap-infra, bootstrap-dev, bootstrap-prd)
  alias = tm_slug(bundle.environment.id)

  input "ci_entry" {
    type        = bool
    description = "Create the GitHub OIDC provider + gha-ci entry role in this account"
    default     = false
  }
  input "ci_env" {
    type        = string
    description = "environment id of the account that holds the GitHub OIDC provider + gha-ci entry role; every other account's deploy role trusts it, so that account bootstraps first"
    default     = "infra"
  }
  input "state_backend" {
    type        = string
    description = "local (first apply) or s3 (after state migration)"
    default     = "local"
    # bootstrap starts on local state; flip to s3 in the scaffold after the first apply + migrate
  }
  input "admin_principal_arns" {
    type        = any
    description = "IAM principal ARNs (users/roles) allowed to assume the deploy role"
    default     = []
  }

  scaffolding {
    path = "/_scaffold-bootstrap.tm.yml"
    name = "bootstrap"
  }
}

define bundle stack "bootstrap" {
  metadata {
    # SPIKE A.3: path MUST embed bundle.environment.id to avoid per-env collision
    path        = "/stacks/aws/${bundle.environment.id}/bootstrap"
    name        = "bootstrap-${bundle.environment.id}"
    description = "Account foundation for ${bundle.environment.id}"
    # 'ci-entry' marks the one account that owns the OIDC provider + gha-ci role.
    tags = tm_concat(
      ["bootstrap", "env-${bundle.environment.id}"],
      bundle.input.ci_entry.value ? ["ci-entry"] : [],
      bundle.input.aws_account_map.value[bundle.environment.id].endpoint != "" ? ["local"] : [],
    )
    # Every non-CI account's tmhs-deploy role trusts arn:...:<ci_env>:role/tmhs-gha-ci.
    # IAM rejects a trust policy naming a principal that does not exist, so the CI
    # account's bootstrap must be applied first.
    after = bundle.input.ci_entry.value ? [] : ["/stacks/aws/${bundle.input.ci_env.value}/bootstrap"]
  }

  component "bootstrap" {
    source = "/components/bootstrap"
    inputs {
      project_prefix = bundle.input.project_prefix.value
      # SPIKE A.3/A.4: use bundle.environment.id directly — no env bundle input needed
      env                  = bundle.environment.id
      account_map          = bundle.input.aws_account_map.value
      github_repo          = bundle.input.github_repo.value
      ci_env               = bundle.input.ci_env.value
      ci_entry             = bundle.input.ci_entry.value
      admin_principal_arns = bundle.input.admin_principal_arns.value
    }
  }

  component "required" {
    source = "/components/providers/required"
    inputs {
      # Task 2 injects aws_account_map and providers_map; map them here
      providers           = { aws = bundle.input.providers_map.value.aws, tls = bundle.input.providers_map.value.tls }
      tofu_version        = bundle.input.tofu_version.value
      account_map         = bundle.input.aws_account_map.value
      env                 = bundle.environment.id
      state_backend       = bundle.input.state_backend.value
      backend_assume_role = false # bootstrap runs on ambient admin creds; deploy role doesn't exist yet
    }
  }

  component "aws" {
    source = "/components/providers/aws"
    inputs {
      account_map  = bundle.input.aws_account_map.value
      env          = bundle.environment.id
      assume_role  = false # ditto — deploy role doesn't exist yet
      default_tags = { Project = "terramate-eks-hubspoke", Env = bundle.environment.id }
    }
  }
}
