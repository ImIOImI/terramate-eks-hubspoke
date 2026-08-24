# config — the entire configuration as data, with per-environment overrides.
#
# defaults() holds the base config shared by every environment. overrides()
# holds only what each environment changes. env(id) deep-merges the two, so a
# consumer asks for the fully-resolved config of one environment and never sees
# the base/override split. Everything env-specific (naming, state addressing)
# derives from env(id), so the whole library stays consistent.
#
# NOTE on merge: symbols are pure and cannot call the Terraform deepmerge
# *module*. deepmerge() below is a pure recursive symbol that does the same job,
# and — unlike a module — its result is usable from other symbols (naming, etc.).

function "project_prefix" {
  return = "tmhs"
}

# Base config. Any key here can be overridden per environment.
function "defaults" {
  return = {
    region              = "us-east-1"
    role                = "spoke"
    hub_env             = "infra"
    kubernetes_version  = "1.33"
    node_instance_types = ["t3.large"]
    node_scaling        = { min = 2, max = 3 }
    addon_versions = {
      "kube-proxy"             = "v1.33.0-eksbuild.2"
      "vpc-cni"                = "v1.19.2-eksbuild.1"
      "coredns"                = "v1.12.1-eksbuild.2"
      "aws-ebs-csi-driver"     = "v1.44.0-eksbuild.1"
      "eks-pod-identity-agent" = "v1.3.7-eksbuild.2"
    }
    tags = {
      Project   = "terramate-eks-hubspoke"
      ManagedBy = "opentofu"
    }
  }
}

# Per-environment overrides — only what differs from defaults().
function "overrides" {
  return = {
    infra = {
      account_id = "111111111111"
      vpc_cidr   = "10.0.0.0/16"
      role       = "hub"
      hub_env    = ""
    }
    dev = {
      account_id = "222222222222"
      vpc_cidr   = "10.1.0.0/16"
    }
    prd = {
      account_id = "333333333333"
      vpc_cidr   = "10.2.0.0/16"
      # Example env-specific override: prd runs a larger, wider node group.
      node_scaling        = { min = 3, max = 6 }
      node_instance_types = ["m5.xlarge"]
    }
  }
}

# Pure recursive deep-merge: `over` wins; two maps merge key-by-key; anything
# else (scalars, lists) is replaced wholesale.
function "deepmerge" {
  parameter "base" { type = any }
  parameter "over" { type = any }
  return = {
    for k in distinct(concat(keys(param.base), keys(param.over))) : k => (
      contains(keys(param.base), k) && contains(keys(param.over), k) && can(keys(param.base[k])) && can(keys(param.over[k]))
      ? symbols::deepmerge(param.base[k], param.over[k])
      : (contains(keys(param.over), k) ? param.over[k] : param.base[k])
    )
  }
}

# The fully-resolved config for one environment.
function "env" {
  parameter "id" { type = string }
  return = symbols::deepmerge(symbols::defaults(), symbols::overrides()[param.id])
}

# --- typed accessors (all derive from the merged env) ------------------------
function "account_id" {
  parameter "id" { type = string }
  return = symbols::env(param.id).account_id
}
function "region" {
  parameter "id" { type = string }
  return = symbols::env(param.id).region
}
function "vpc_cidr" {
  parameter "id" { type = string }
  return = symbols::env(param.id).vpc_cidr
}
function "role" {
  parameter "id" { type = string }
  return = symbols::env(param.id).role
}
function "hub_env" {
  parameter "id" { type = string }
  return = symbols::env(param.id).hub_env
}
function "kubernetes_version" {
  parameter "id" { type = string }
  return = symbols::env(param.id).kubernetes_version
}
function "node_instance_types" {
  parameter "id" { type = string }
  return = symbols::env(param.id).node_instance_types
}
function "node_scaling" {
  parameter "id" { type = string }
  return = symbols::env(param.id).node_scaling
}
function "addon_versions" {
  parameter "id" { type = string }
  return = symbols::env(param.id).addon_versions
}
function "tags" {
  parameter "id" { type = string }
  return = symbols::env(param.id).tags
}
function "cluster_name" {
  parameter "id" { type = string }
  return = "${symbols::project_prefix()}-eks-${param.id}"
}

# --- hub helpers: give a spoke's env id, get its HUB's value -----------------
# So roots pass only their own env instead of nesting hub_env() everywhere.
function "hub_cluster_name" {
  parameter "id" { type = string }
  return = symbols::cluster_name(symbols::hub_env(param.id))
}
function "hub_remote_state" {
  parameter "id" { type = string }
  parameter "tier" { type = string }
  return = symbols::remote_state(symbols::hub_env(param.id), param.tier)
}

# --- global (non-per-env) knobs ---------------------------------------------
function "github_repo" {
  return = "ImIOImI/terramate-eks-hubspoke"
}

# --- state addressing --------------------------------------------------------
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
