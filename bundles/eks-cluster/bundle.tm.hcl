define "bundle" "metadata" {
  class       = "eks-cluster"
  version     = "0.1.0"
  name        = "EKS Cluster"
  description = "One environment's full EKS stack tree: network -> cluster -> nodes -> provisioning. Fanned out per environment (hub in infra, spokes in dev/prd) via environments."
}

# SPIKE A.2: a bundle must opt in to environments or the YAML environments: key errors.
define "bundle" "environments" {
  required = true
}

define "bundle" {
  # Disambiguates per-env instances in terramate output (eks-cluster-infra, -dev, -prd).
  alias = tm_slug(bundle.environment.id)

  input "role" {
    type        = string
    description = "cluster role: hub or spoke"
    # constrain the scaffold prompt; hub in infra, spoke in dev/prd
    prompt {
      text    = "Cluster role:"
      options = ["hub", "spoke"]
    }
  }
  input "hub_env" {
    type        = string
    description = "environment id of the hub cluster (spokes only; empty for the hub itself)"
    default     = ""
  }
  input "node_instance_types" {
    type        = any
    description = "list of EC2 instance type strings for the managed node group"
    default     = ["t3.large"]
  }
  input "node_scaling" {
    type        = any
    description = "object { min, max } controlling the managed node group scaling bounds"
    default     = { min = 2, max = 3 }
  }
  input "terraform_modules" {
    type        = any
    description = "map module name -> { source, version }; expects .vpc and .eks"
  }
  input "addon_versions" {
    type        = any
    description = "map add-on name -> version string (kube-proxy, vpc-cni, coredns, aws-ebs-csi-driver, eks-pod-identity-agent)"
  }
  input "argocd_chart_version" {
    type        = string
    description = "Helm chart version for argo-cd (hub only)"
  }
  input "spoke_envs" {
    type        = any
    description = "list of spoke environment ids the hub ArgoCD controller may assume into (hub only)"
    default     = ["dev", "prd"]
  }
  input "vpc_cidr" {
    type        = string
    description = "CIDR block for this env's VPC"
    default     = "10.0.0.0/16"
  }

  # ── derived stack ids ────────────────────────────────────────────────────────
  # Cross-stack outputs-sharing needs each producer stack's id as from_stack_id.
  # Those ids are NOT minted UUIDs here: make/create-stacks.sh seeds every
  # stack.tm.hcl with an id derived from the stack path (see make/stack-ids.sh),
  # and Terramate only mints a UUID when that file is absent. So the same formula
  # reproduces them below and no wiring input is needed.
  #
  #   /stacks/aws/<env>/eks/<label>  ->  <env>-eks-<label>
  #
  # Keep these two expressions and make/stack-ids.sh's id_for() in agreement --
  # `make check-ids` fails the build if they ever drift.

  scaffolding {
    path = "/_scaffold-cluster.tm.yml"
    name = "cluster"
  }
}

# ============================================================================
# network — VPC + subnets. No upstream dependency.
# ============================================================================
define bundle stack "network" {
  metadata {
    path        = "/stacks/aws/${bundle.environment.id}/eks/network"
    name        = "eks-network-${bundle.environment.id}"
    description = "VPC + subnets for ${bundle.environment.id}"
    tags        = ["eks", "network", "env-${bundle.environment.id}", "role-${bundle.input.role.value}"]
    # Anchors the whole eks chain behind this account's bootstrap: every stack here
    # keys state to the S3 bucket + lock table + tmhs-deploy role that bootstrap
    # creates, so `tofu init` fails until it exists. cluster/nodes/provisioning
    # inherit the edge transitively through network.
    after = ["/stacks/aws/${bundle.environment.id}/bootstrap"]
  }

  component "network" {
    source = "/components/network"
    inputs {
      terraform_modules = bundle.input.terraform_modules.value
      cluster_name      = bundle.input.aws_account_map.value[bundle.environment.id].cluster_name
      region            = bundle.input.aws_account_map.value[bundle.environment.id].region
      vpc_cidr          = bundle.input.vpc_cidr.value
    }
  }

  component "required" {
    source = "/components/providers/required"
    inputs {
      providers           = { aws = bundle.input.providers_map.value.aws }
      tofu_version        = bundle.input.tofu_version.value
      account_map         = bundle.input.aws_account_map.value
      env                 = bundle.environment.id
      state_backend       = "s3"
      backend_assume_role = true
    }
  }

  component "aws" {
    source = "/components/providers/aws"
    inputs {
      account_map  = bundle.input.aws_account_map.value
      env          = bundle.environment.id
      assume_role  = true
      default_tags = { Project = "terramate-eks-hubspoke", Env = bundle.environment.id }
    }
  }
}

# ============================================================================
# cluster — EKS control plane. Depends on network (vpc_id, subnet_ids).
# ============================================================================
define bundle stack "cluster" {
  metadata {
    path        = "/stacks/aws/${bundle.environment.id}/eks/cluster"
    name        = "eks-cluster-${bundle.environment.id}"
    description = "EKS control plane for ${bundle.environment.id}"
    tags        = ["eks", "cluster", "env-${bundle.environment.id}", "role-${bundle.input.role.value}"]
    after       = ["/stacks/aws/${bundle.environment.id}/eks/network"]
  }

  component "cluster" {
    source = "/components/eks-cluster"
    inputs {
      terraform_modules = bundle.input.terraform_modules.value
      cluster_name      = bundle.input.aws_account_map.value[bundle.environment.id].cluster_name
      env               = bundle.environment.id
      role              = bundle.input.role.value
      account_map       = bundle.input.aws_account_map.value
      project_prefix    = bundle.input.project_prefix.value
      network_stack_id  = "${bundle.environment.id}-eks-network"
    }
  }

  component "required" {
    source = "/components/providers/required"
    inputs {
      providers           = { aws = bundle.input.providers_map.value.aws }
      tofu_version        = bundle.input.tofu_version.value
      account_map         = bundle.input.aws_account_map.value
      env                 = bundle.environment.id
      state_backend       = "s3"
      backend_assume_role = true
    }
  }

  component "aws" {
    source = "/components/providers/aws"
    inputs {
      account_map  = bundle.input.aws_account_map.value
      env          = bundle.environment.id
      assume_role  = true
      default_tags = { Project = "terramate-eks-hubspoke", Env = bundle.environment.id }
    }
  }
}

# ============================================================================
# nodes — managed node group + ordered CNI/pod-identity add-ons.
# Depends on cluster (cluster_service_cidr) and network (subnet_ids).
# ============================================================================
define bundle stack "nodes" {
  metadata {
    path        = "/stacks/aws/${bundle.environment.id}/eks/nodes"
    name        = "eks-nodes-${bundle.environment.id}"
    description = "Managed node group for ${bundle.environment.id}"
    tags        = ["eks", "nodes", "env-${bundle.environment.id}", "role-${bundle.input.role.value}"]
    after       = ["/stacks/aws/${bundle.environment.id}/eks/cluster"]
  }

  component "nodes" {
    source = "/components/eks-nodes"
    inputs {
      cluster_name        = bundle.input.aws_account_map.value[bundle.environment.id].cluster_name
      addon_versions      = bundle.input.addon_versions.value
      node_instance_types = bundle.input.node_instance_types.value
      node_scaling        = bundle.input.node_scaling.value
      terraform_modules   = bundle.input.terraform_modules.value
      network_stack_id    = "${bundle.environment.id}-eks-network"
      cluster_stack_id    = "${bundle.environment.id}-eks-cluster"
    }
  }

  component "required" {
    source = "/components/providers/required"
    inputs {
      providers           = { aws = bundle.input.providers_map.value.aws }
      tofu_version        = bundle.input.tofu_version.value
      account_map         = bundle.input.aws_account_map.value
      env                 = bundle.environment.id
      state_backend       = "s3"
      backend_assume_role = true
    }
  }

  component "aws" {
    source = "/components/providers/aws"
    inputs {
      account_map  = bundle.input.aws_account_map.value
      env          = bundle.environment.id
      assume_role  = true
      default_tags = { Project = "terramate-eks-hubspoke", Env = bundle.environment.id }
    }
  }
}

# ============================================================================
# provisioning — core add-ons (both roles) + ArgoCD (hub or spoke) + k8s/helm
# providers. Depends on nodes; spokes ALSO depend on the hub's provisioning
# (so the hub ArgoCD + cluster secret target exist first).
# ============================================================================
define bundle stack "provisioning" {
  metadata {
    path        = "/stacks/aws/${bundle.environment.id}/eks/provisioning"
    name        = "eks-provisioning-${bundle.environment.id}"
    description = "Core add-ons + ArgoCD (${bundle.input.role.value}) for ${bundle.environment.id}"
    tags        = ["eks", "provisioning", "env-${bundle.environment.id}", "role-${bundle.input.role.value}"]
    after = tm_concat(
      ["/stacks/aws/${bundle.environment.id}/eks/nodes"],
      bundle.input.role.value == "spoke" ? ["/stacks/aws/${bundle.input.hub_env.value}/eks/provisioning"] : [],
    )
  }

  # CoreDNS + EBS CSI — both roles.
  component "core-addons" {
    source = "/components/eks-core-addons"
    inputs {
      cluster_name   = bundle.input.aws_account_map.value[bundle.environment.id].cluster_name
      env            = bundle.environment.id
      account_map    = bundle.input.aws_account_map.value
      project_prefix = bundle.input.project_prefix.value
      addon_versions = bundle.input.addon_versions.value
    }
  }

  # ArgoCD hub — enabled only when role == hub (conditional components unsupported).
  component "argocd-hub" {
    source = "/components/argocd-hub"
    inputs {
      enabled              = bundle.input.role.value == "hub"
      cluster_name         = bundle.input.aws_account_map.value[bundle.environment.id].cluster_name
      env                  = bundle.environment.id
      account_map          = bundle.input.aws_account_map.value
      project_prefix       = bundle.input.project_prefix.value
      argocd_chart_version = bundle.input.argocd_chart_version.value
      spoke_envs           = bundle.input.spoke_envs.value
    }
  }

  # ArgoCD spoke — enabled only when role == spoke.
  component "argocd-spoke" {
    source = "/components/argocd-spoke"
    inputs {
      enabled          = bundle.input.role.value == "spoke"
      cluster_name     = bundle.input.aws_account_map.value[bundle.environment.id].cluster_name
      env              = bundle.environment.id
      hub_env          = bundle.input.hub_env.value
      account_map      = bundle.input.aws_account_map.value
      project_prefix   = bundle.input.project_prefix.value
      cluster_stack_id = "${bundle.environment.id}-eks-cluster"
    }
  }

  # kubernetes (+ helm on hub, + kubernetes.hub alias on spokes) providers.
  component "kubernetes" {
    source = "/components/providers/kubernetes"
    inputs {
      cluster_name         = bundle.input.aws_account_map.value[bundle.environment.id].cluster_name
      env                  = bundle.environment.id
      account_map          = bundle.input.aws_account_map.value
      cluster_stack_id     = "${bundle.environment.id}-eks-cluster"
      include_helm         = bundle.input.role.value == "hub"
      hub_env              = bundle.input.role.value == "spoke" ? bundle.input.hub_env.value : ""
      hub_cluster_name     = bundle.input.role.value == "spoke" ? bundle.input.aws_account_map.value[bundle.input.hub_env.value].cluster_name : ""
      hub_cluster_stack_id = bundle.input.role.value == "spoke" ? "${bundle.input.hub_env.value}-eks-cluster" : ""
    }
  }

  component "required" {
    source = "/components/providers/required"
    inputs {
      # aws + kubernetes always; helm on the hub (where the ArgoCD Helm release lives).
      providers = bundle.input.role.value == "hub" ? {
        aws        = bundle.input.providers_map.value.aws
        kubernetes = bundle.input.providers_map.value.kubernetes
        helm       = bundle.input.providers_map.value.helm
        } : {
        aws        = bundle.input.providers_map.value.aws
        kubernetes = bundle.input.providers_map.value.kubernetes
      }
      tofu_version        = bundle.input.tofu_version.value
      account_map         = bundle.input.aws_account_map.value
      env                 = bundle.environment.id
      state_backend       = "s3"
      backend_assume_role = true
    }
  }

  component "aws" {
    source = "/components/providers/aws"
    inputs {
      account_map  = bundle.input.aws_account_map.value
      env          = bundle.environment.id
      assume_role  = true
      default_tags = { Project = "terramate-eks-hubspoke", Env = bundle.environment.id }
    }
  }
}
