// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

module "eks" {
  access_entries = {
    deploy = {
      policy_associations = {
        admin = {
          access_scope = {
            type = "cluster"
          }
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
        }
      }
      principal_arn = "arn:aws:iam::111111111111:role/tmhs-deploy"
    }
  }
  addons                                   = {}
  enable_cluster_creator_admin_permissions = true
  enable_irsa                              = true
  endpoint_public_access                   = true
  kubernetes_version                       = "1.33"
  name                                     = "tmhs-eks-infra"
  source                                   = "terraform-aws-modules/eks/aws"
  subnet_ids                               = var.private_subnet_ids
  version                                  = "21.24.0"
  vpc_id                                   = var.vpc_id
}
