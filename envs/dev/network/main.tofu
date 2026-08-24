language {
  experiments = [symbol_libraries]
}
symbols "cfg" {
  source = "../../../lib/config"
}
symbols "name" {
  source = "../../../lib/naming"
}

terraform {
  required_version = ">= 1.11.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }
  backend "s3" {
    bucket = "tmhs-state-dev-222222222222"
    key    = "stacks/aws/dev/network/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = symbols::cfg::region("dev")
  assume_role {
    role_arn = symbols::name::deploy_role_arn("dev")
  }
  default_tags {
    tags = symbols::cfg::tags()
  }
}

module "network" {
  source = "../../../modules/network"

  cluster_name = symbols::cfg::cluster_name("dev")
  region       = symbols::cfg::region("dev")
  vpc_cidr     = symbols::cfg::vpc_cidr("dev")
  tags         = symbols::cfg::tags()
}

output "vpc_id" { value = module.network.vpc_id }
output "private_subnet_ids" { value = module.network.private_subnet_ids }
