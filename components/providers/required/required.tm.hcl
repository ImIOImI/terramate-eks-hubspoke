generate_hcl "_tmgen-terraform.tf" {
  condition = component.input.state_backend.value == "s3"
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
          attributes = { role_arn = let.acct.deploy_role_arn }
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
