// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

module "eks" {
  access_entries = {
    argocd = {
      policy_associations = {
        admin = {
          access_scope = {
            type = "cluster"
          }
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
        }
      }
      principal_arn = "arn:aws:iam::222222222222:role/tmhs-argocd-spoke-access"
    }
    deploy = {
      policy_associations = {
        admin = {
          access_scope = {
            type = "cluster"
          }
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
        }
      }
      principal_arn = "arn:aws:iam::222222222222:role/tmhs-deploy"
    }
  }
  addons                                   = {}
  enable_cluster_creator_admin_permissions = true
  endpoint_public_access                   = true
  kubernetes_version                       = "1.33"
  name                                     = "tmhs-eks-dev"
  source                                   = "terraform-aws-modules/eks/aws"
  subnet_ids                               = var.private_subnet_ids
  version                                  = "21.24.0"
  vpc_id                                   = var.vpc_id
}
