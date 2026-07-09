# ---------------------------------------------------------------------------
# Sharing inputs: vpc_id + private_subnet_ids (consumed from network stack).
# These generate _tmgen-sharing.tf (variable "vpc_id" / "private_subnet_ids")
# on the second terramate generate pass. Consume as var.* in resource/module
# args only — never in data-source filters (mock footgun, SPIKE-FINDINGS C.5).
# ---------------------------------------------------------------------------
generate_hcl "_tmgen-sharing-inputs.tm.hcl" {
  content {
    input "vpc_id" {
      backend       = "default"
      from_stack_id = component.input.network_stack_id.value
      value         = outputs.vpc_id.value
      mock          = "vpc-00000000000000000"
    }
    input "private_subnet_ids" {
      backend       = "default"
      from_stack_id = component.input.network_stack_id.value
      value         = outputs.private_subnet_ids.value
      mock          = ["subnet-00000000000000000", "subnet-00000000000000001"]
    }
  }
}

# ---------------------------------------------------------------------------
# Sharing output: cluster_service_cidr (consumed by nodes component).
# ---------------------------------------------------------------------------
generate_hcl "_tmgen-sharing-outputs.tm.hcl" {
  content {
    output "cluster_service_cidr" {
      backend = "default"
      value   = module.eks.cluster_service_cidr
    }
  }
}

# ---------------------------------------------------------------------------
# EKS control plane.
# Verified against terraform-aws-modules/eks v21.0.0 variables.tf / outputs.tf:
#   name                                   -> v21 (was cluster_name in v20)
#   kubernetes_version                     -> v21 (was cluster_version in v20)
#   endpoint_public_access                 -> v21 (was cluster_endpoint_public_access in v20)
#   addons = {}                            -> v21 default is {}; explicit to document intent
#   vpc_id, subnet_ids                     -> unchanged
#   enable_cluster_creator_admin_permissions -> unchanged, default false
#   access_entries policy_associations/access_scope -> unchanged shape
#   cluster_service_cidr output            -> confirmed present in v21 outputs.tf
# ---------------------------------------------------------------------------
generate_hcl "_tmgen-cluster.tf" {
  lets {
    acct = component.input.account_map.value[component.input.env.value]
  }
  content {
    module "eks" {
      source  = component.input.terraform_modules.value.eks.source
      version = component.input.terraform_modules.value.eks.version

      name               = component.input.cluster_name.value
      kubernetes_version = "1.33"

      endpoint_public_access = true

      # Add-ons deliberately deferred to nodes/provisioning stacks.
      # v21 default is {} so this is a no-op, but explicit for documentation.
      addons = {}

      vpc_id     = var.vpc_id
      subnet_ids = var.private_subnet_ids

      enable_cluster_creator_admin_permissions = true

      access_entries = tm_merge(
        {
          deploy = {
            principal_arn = let.acct.deploy_role_arn
            policy_associations = {
              admin = {
                policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
                access_scope = { type = "cluster" }
              }
            }
          }
        },
        component.input.role.value == "spoke" ? {
          argocd = {
            principal_arn = "arn:aws:iam::${let.acct.account_id}:role/${component.input.project_prefix.value}-argocd-spoke-access"
            policy_associations = {
              admin = {
                policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
                access_scope = { type = "cluster" }
              }
            }
          }
        } : {}
      )
    }
  }
}
