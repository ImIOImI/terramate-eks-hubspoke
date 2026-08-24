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
    aws        = { source = "hashicorp/aws", version = "~> 6.0" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.38" }
  }
  backend "s3" {
    bucket = "tmhs-state-dev-222222222222"
    key    = "stacks/aws/dev/provisioning/terraform.tfstate"
    region = "us-east-1"
  }
}

# This spoke's own cluster state (endpoint/CA for the registration secret).
data "terraform_remote_state" "cluster" {
  backend = "s3"
  config  = symbols::cfg::remote_state("dev", "cluster")
}

# Cross-ENV read: the hub cluster's state, so we can register into it.
data "terraform_remote_state" "hub_cluster" {
  backend = "s3"
  config  = symbols::cfg::remote_state("infra", "cluster")
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

# Hub-cluster kubernetes provider: talks to infra's cluster, assuming infra's
# deploy role. Every value is symbol-derived or read from the hub's remote state.
provider "kubernetes" {
  alias                  = "hub"
  host                   = data.terraform_remote_state.hub_cluster.outputs.cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.hub_cluster.outputs.cluster_ca)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks", "get-token",
      "--cluster-name", symbols::cfg::cluster_name("infra"),
      "--role-arn", symbols::name::deploy_role_arn("infra"),
    ]
  }
}

module "provisioning" {
  source = "../../../modules/provisioning"
  providers = {
    aws            = aws
    kubernetes.hub = kubernetes.hub
  }

  cluster_name     = symbols::cfg::cluster_name("dev")
  env              = "dev"
  addon_versions   = symbols::cfg::addon_versions()
  controller_arn   = symbols::name::argocd_controller_arn("infra")
  cluster_endpoint = data.terraform_remote_state.cluster.outputs.cluster_endpoint
  cluster_ca       = data.terraform_remote_state.cluster.outputs.cluster_ca
}
