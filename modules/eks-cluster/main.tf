terraform {
  required_version = ">= 1.11.0"
}

variable "cluster_name" { type = string }
variable "kubernetes_version" { type = string }
variable "enable_irsa" {
  type    = bool
  default = true
}
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "deploy_role_arn" { type = string }

# Spoke clusters grant the hub ArgoCD controller cluster-admin via this ARN.
# Empty on the hub itself.
variable "spoke_access_arn" {
  type    = string
  default = ""
}

locals {
  admin_scope = {
    policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
    access_scope = { type = "cluster" }
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name                   = var.cluster_name
  kubernetes_version     = var.kubernetes_version
  endpoint_public_access = true
  addons                 = {}

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  enable_cluster_creator_admin_permissions = true
  enable_irsa                              = var.enable_irsa

  access_entries = merge(
    {
      deploy = {
        principal_arn       = var.deploy_role_arn
        policy_associations = { admin = local.admin_scope }
      }
    },
    var.spoke_access_arn != "" ? {
      argocd = {
        principal_arn       = var.spoke_access_arn
        policy_associations = { admin = local.admin_scope }
      }
    } : {}
  )
}

output "cluster_service_cidr" { value = module.eks.cluster_service_cidr }
output "cluster_name" { value = module.eks.cluster_name }
output "cluster_endpoint" { value = module.eks.cluster_endpoint }
output "cluster_ca" { value = module.eks.cluster_certificate_authority_data }
output "oidc_issuer" { value = module.eks.cluster_oidc_issuer_url }
