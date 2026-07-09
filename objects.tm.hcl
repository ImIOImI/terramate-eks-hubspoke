generate_hcl "_tmgen-input-env.tm.hcl" {
  condition = tm_alltrue([
    tm_contains(terramate.stack.tags, "default"),
    !tm_contains(terramate.stack.tags, "nogen"),
  ])
  content {
    define "bundle" {
      input "env" {
        type        = string
        description = "Target environment"
        prompt      = "Environment:"
        options     = ["infra", "dev", "prd"]
      }
    }
  }
}

generate_hcl "_tmgen-input-account-map.tm.hcl" {
  condition = tm_alltrue([
    tm_contains(terramate.stack.tags, "default"),
    !tm_contains(terramate.stack.tags, "nogen"),
  ])
  lets {
    enriched = {
      for env, cfg in global.envs : env => {
        account_id      = cfg.account_id
        region          = cfg.region
        deploy_role_arn = "arn:aws:iam::${cfg.account_id}:role/${global.project_prefix}-deploy"
        state_bucket    = "${global.project_prefix}-state-${env}-${cfg.account_id}"
        lock_table      = "${global.project_prefix}-locks-${env}"
        cluster_name    = "${global.project_prefix}-eks-${env}"
      }
    }
  }
  content {
    define "bundle" {
      input "aws_account_map" {
        type    = any
        default = let.enriched
      }
    }
  }
}

generate_hcl "_tmgen-input-providers-map.tm.hcl" {
  condition = tm_alltrue([
    tm_contains(terramate.stack.tags, "default"),
    !tm_contains(terramate.stack.tags, "nogen"),
  ])
  content {
    define "bundle" {
      input "providers_map" {
        type    = any
        default = global.terraform.providers
      }
    }
  }
}

generate_hcl "_tmgen-input-project.tm.hcl" {
  condition = tm_alltrue([
    tm_contains(terramate.stack.tags, "default"),
    !tm_contains(terramate.stack.tags, "nogen"),
  ])
  content {
    define "bundle" {
      input "project_prefix" {
        type    = string
        default = global.project_prefix
      }

      input "github_repo" {
        type    = string
        default = global.github_repo
      }

      input "tofu_version" {
        type    = string
        default = global.tofu_version
      }
    }
  }
}
