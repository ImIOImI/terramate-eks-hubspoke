generate_hcl "_tmgen-terraform.tf" {
  condition = component.input.state_backend.value == "s3" && component.input.account_map.value[component.input.env.value].endpoint == ""
  lets {
    acct = component.input.account_map.value[component.input.env.value]
  }
  content {
    terraform {
      required_version = component.input.tofu_version.value
      tm_dynamic "required_providers" {
        attributes = {
          for k, v in component.input.providers.value : k => {
            source  = v.source
            version = v.version
          }
        }
      }
      backend "s3" {
        region         = let.acct.region
        bucket         = let.acct.state_bucket
        key            = "stacks/by-id/${terramate.stack.id}/terraform.tfstate"
        encrypt        = true
        dynamodb_table = let.acct.lock_table
        tm_dynamic "assume_role" {
          condition  = component.input.backend_assume_role.value
          attributes = { role_arn = component.input.deploy_role_arn.value != "" ? component.input.deploy_role_arn.value : let.acct.deploy_role_arn }
        }
      }
    }
  }
}


# ---------------------------------------------------------------------------
# Local (MiniStack) s3 backend.
# Kept as a separate block rather than conditionals inside the AWS one so the
# real-AWS output stays byte-identical.
#
# Two things differ from the aws provider's equivalent config:
#   - `endpoints` is an ARGUMENT here (endpoints = {...}), not a nested block
#   - no assume_role: MiniStack authenticates purely on the 12-digit access key,
#     which it turns into the account id. There is no role to assume.
# ---------------------------------------------------------------------------
generate_hcl "_tmgen-terraform.tf" {
  condition = component.input.state_backend.value == "s3" && component.input.account_map.value[component.input.env.value].endpoint != ""
  lets {
    acct = component.input.account_map.value[component.input.env.value]
  }
  content {
    terraform {
      required_version = component.input.tofu_version.value
      tm_dynamic "required_providers" {
        attributes = {
          for k, v in component.input.providers.value : k => {
            source  = v.source
            version = v.version
          }
        }
      }
      backend "s3" {
        region                      = let.acct.region
        bucket                      = let.acct.state_bucket
        key                         = "stacks/by-id/${terramate.stack.id}/terraform.tfstate"
        encrypt                     = true
        dynamodb_table              = let.acct.lock_table
        access_key                  = let.acct.account_id
        secret_key                  = "test"
        use_path_style              = true
        skip_credentials_validation = true
        skip_metadata_api_check     = true
        skip_requesting_account_id  = true
        endpoints = {
          for svc in ["s3", "dynamodb", "iam", "sts"] : svc => let.acct.endpoint
        }
      }
    }
  }
}

generate_hcl "_tmgen-terraform.tf" {
  condition = component.input.state_backend.value == "local"
  content {
    terraform {
      required_version = component.input.tofu_version.value
      tm_dynamic "required_providers" {
        attributes = {
          for k, v in component.input.providers.value : k => {
            source  = v.source
            version = v.version
          }
        }
      }
      backend "local" {}
    }
  }
}

generate_file ".opentofu-version" {
  content = "${component.input.tofu_version.value}\n"
}
