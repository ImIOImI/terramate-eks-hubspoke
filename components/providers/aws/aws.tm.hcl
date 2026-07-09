generate_hcl "_tmgen-provider-aws.tf" {
  lets {
    acct = component.input.account_map.value[component.input.env.value]
  }
  content {
    provider "aws" {
      region = let.acct.region
      tm_dynamic "assume_role" {
        condition  = component.input.assume_role.value
        attributes = { role_arn = let.acct.deploy_role_arn }
      }
      default_tags {
        tags = component.input.default_tags.value
      }
    }
  }
}
