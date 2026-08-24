language {
  experiments = [symbol_libraries]
}
symbols "cfg" {
  source = "../../../lib/config"
}
symbols "name" {
  source = "../../../lib/naming"
}

# The terraform{} block is a static context — no symbols/functions allowed here
# (same rule as variables). This literal boilerplate is the one thing per root
# that symbols can't DRY; Terramate codegen used to emit it.
terraform {
  required_version = ">= 1.11.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
    tls = { source = "hashicorp/tls", version = "~> 4.0" }
  }
  # NOTE: bootstrap creates this bucket, so the first apply runs on a local
  # backend and then migrates to s3. Shown as s3 for parity with the other tiers.
  backend "s3" {
    bucket = "tmhs-state-dev-222222222222"
    key    = "stacks/aws/dev/bootstrap/terraform.tfstate"
    region = "us-east-1"
  }
}

# Bootstrap runs on ambient admin creds — no assume_role (the deploy role does
# not exist yet).
provider "aws" {
  region = symbols::cfg::region("dev")
  default_tags {
    tags = symbols::cfg::tags("dev")
  }
}

module "bootstrap" {
  source = "../../../modules/bootstrap"

  project_prefix = symbols::cfg::project_prefix()
  state_bucket   = symbols::cfg::state_bucket("dev")
  lock_table     = symbols::cfg::lock_table("dev")
  static_trust   = [symbols::name::gha_ci_arn("infra")]
  github_repo    = symbols::cfg::github_repo()
  oidc_entry     = false
}
