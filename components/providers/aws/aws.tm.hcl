generate_hcl "_tmgen-provider-aws.tf" {
  condition = component.input.account_map.value[component.input.env.value].endpoint == ""
  lets {
    acct = component.input.account_map.value[component.input.env.value]
  }
  content {
    provider "aws" {
      region = let.acct.region
      tm_dynamic "assume_role" {
        condition  = component.input.assume_role.value
        attributes = { role_arn = component.input.deploy_role_arn.value != "" ? component.input.deploy_role_arn.value : let.acct.deploy_role_arn }
      }
      default_tags {
        tags = component.input.default_tags.value
      }
    }
  }
}

# ---------------------------------------------------------------------------
# Local (MiniStack) aws provider. Separate block so the real-AWS output above
# stays byte-identical. The 12-digit access key IS the account id in MiniStack,
# and there is no role to assume.
# ---------------------------------------------------------------------------
generate_hcl "_tmgen-provider-aws.tf" {
  condition = component.input.account_map.value[component.input.env.value].endpoint != ""
  lets {
    acct = component.input.account_map.value[component.input.env.value]
  }
  content {
    provider "aws" {
      region                      = let.acct.region
      access_key                  = let.acct.account_id
      secret_key                  = "test"
      s3_use_path_style           = true
      skip_credentials_validation = true
      skip_metadata_api_check     = true
      skip_requesting_account_id  = true
      tm_dynamic "endpoints" {
        attributes = {
          for svc in global.ministack_services : svc => let.acct.endpoint
        }
      }
      default_tags {
        tags = component.input.default_tags.value
      }
    }
  }
}
