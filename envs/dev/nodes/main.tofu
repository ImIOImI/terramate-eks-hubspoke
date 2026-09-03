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
    key    = "stacks/aws/dev/nodes/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = symbols::cfg::region("dev")
  assume_role {
    role_arn = symbols::name::deploy_role_arn("dev")
  }
  default_tags {
    tags = symbols::cfg::tags("dev")
  }
}

data "terraform_remote_state" "network" {
  backend = "s3"
  config  = symbols::cfg::remote_state("dev", "network")
}
data "terraform_remote_state" "cluster" {
  backend = "s3"
  config  = symbols::cfg::remote_state("dev", "cluster")
}

module "nodes" {
  source = "../../../modules/eks-nodes"

  cluster_name         = symbols::cfg::cluster_name("dev")
  kubernetes_version   = symbols::cfg::kubernetes_version("dev")
  private_subnet_ids   = data.terraform_remote_state.network.outputs.private_subnet_ids
  cluster_service_cidr = data.terraform_remote_state.cluster.outputs.cluster_service_cidr
  node_instance_types  = symbols::cfg::node_instance_types("dev")
  node_scaling         = symbols::cfg::node_scaling("dev")
  addon_versions       = symbols::cfg::addon_versions("dev")
}
