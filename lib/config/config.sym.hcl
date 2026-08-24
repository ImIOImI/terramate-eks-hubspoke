# config — the shared data layer (was Terramate globals + objects/inputs).
# Everything env-specific is derived here from one envs() table, so roots never
# hard-code an account id, region, bucket name, or version.

function "project_prefix" {
  return = "tmhs"
}

# The one source of truth for environments (was global.envs + the enriched
# account-map). Spokes: dev, prd. Hub: infra. (MiniStack ci-hub omitted from
# this PoC slice; it slots in as another entry with an `endpoint`.)
function "envs" {
  return = {
    infra = { account_id = "111111111111", region = "us-east-1", vpc_cidr = "10.0.0.0/16" }
    dev   = { account_id = "222222222222", region = "us-east-1", vpc_cidr = "10.1.0.0/16" }
    prd   = { account_id = "333333333333", region = "us-east-1", vpc_cidr = "10.2.0.0/16" }
  }
}

function "env" {
  parameter "id" { type = string }
  return = symbols::envs()[param.id]
}
function "account_id" {
  parameter "id" { type = string }
  return = symbols::envs()[param.id].account_id
}
function "region" {
  parameter "id" { type = string }
  return = symbols::envs()[param.id].region
}
function "vpc_cidr" {
  parameter "id" { type = string }
  return = symbols::envs()[param.id].vpc_cidr
}
function "cluster_name" {
  parameter "id" { type = string }
  return = "${symbols::project_prefix()}-eks-${param.id}"
}

function "tofu_version" {
  return = ">= 1.11.0"
}
function "tags" {
  return = {
    Project   = "terramate-eks-hubspoke"
    ManagedBy = "opentofu"
  }
}
function "provider_versions" {
  return = {
    aws        = { source = "hashicorp/aws", version = "~> 6.0" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.38" }
    helm       = { source = "hashicorp/helm", version = "~> 3.0" }
    tls        = { source = "hashicorp/tls", version = "~> 4.0" }
  }
}
function "github_repo" {
  return = "ImIOImI/terramate-eks-hubspoke"
}

# --- EKS shape defaults (were bundle input defaults) -------------------------
function "kubernetes_version" {
  return = "1.33"
}
function "node_instance_types" {
  return = ["t3.large"]
}
function "node_scaling" {
  return = { min = 2, max = 3 }
}
function "addon_versions" {
  return = {
    "kube-proxy"             = "v1.33.0-eksbuild.2"
    "vpc-cni"                = "v1.19.2-eksbuild.1"
    "coredns"                = "v1.12.1-eksbuild.2"
    "aws-ebs-csi-driver"     = "v1.44.0-eksbuild.1"
    "eks-pod-identity-agent" = "v1.3.7-eksbuild.2"
  }
}

# --- state addressing --------------------------------------------------------
# Was: per-stack backend "s3" config + Terramate outputs-sharing.
# remote_state(env,tier) returns the exact config object a
# `data "terraform_remote_state"` block needs — the symbol assembles the
# address; the (impure) read stays native in the root.
function "state_bucket" {
  parameter "env" { type = string }
  return = "${symbols::project_prefix()}-state-${param.env}-${symbols::account_id(param.env)}"
}
function "lock_table" {
  parameter "env" { type = string }
  return = "${symbols::project_prefix()}-locks-${param.env}"
}
function "state_key" {
  parameter "env" { type = string }
  parameter "tier" { type = string }
  return = "stacks/aws/${param.env}/${param.tier}/terraform.tfstate"
}
function "remote_state" {
  parameter "env" { type = string }
  parameter "tier" { type = string }
  return = {
    bucket = symbols::state_bucket(param.env)
    key    = symbols::state_key(param.env, param.tier)
    region = symbols::region(param.env)
  }
}
