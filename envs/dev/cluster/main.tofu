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
    key    = "stacks/aws/dev/cluster/terraform.tfstate"
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

# Cross-tier wiring — config object comes from the symbol, the read is native.
data "terraform_remote_state" "network" {
  backend = "s3"
  config  = symbols::cfg::remote_state("dev", "network")
}

module "cluster" {
  source = "../../../modules/eks-cluster"

  cluster_name       = symbols::cfg::cluster_name("dev")
  kubernetes_version = symbols::cfg::kubernetes_version("dev")
  vpc_id             = data.terraform_remote_state.network.outputs.vpc_id
  private_subnet_ids = data.terraform_remote_state.network.outputs.private_subnet_ids
  deploy_role_arn    = symbols::name::deploy_role_arn("dev")
  # dev is a spoke: grant the hub ArgoCD controller cluster-admin.
  spoke_access_arn = symbols::name::spoke_access_arn("dev")
}

output "cluster_service_cidr" { value = module.cluster.cluster_service_cidr }
output "cluster_endpoint" { value = module.cluster.cluster_endpoint }
output "cluster_ca" { value = module.cluster.cluster_ca }
output "cluster_name" { value = module.cluster.cluster_name }
