// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

define "bundle" {
  input "aws_account_map" {
    default = {
      ci = {
        account_id      = "000000000099"
        cluster_name    = "tmhs-eks-ci"
        deploy_role_arn = "arn:aws:iam::000000000099:role/tmhs-deploy"
        endpoint        = "http://localhost:4566"
        lock_table      = "tmhs-locks-ci"
        region          = "us-east-1"
        state_bucket    = "tmhs-state-ci-000000000099"
      }
      dev = {
        account_id      = "222222222222"
        cluster_name    = "tmhs-eks-dev"
        deploy_role_arn = "arn:aws:iam::222222222222:role/tmhs-deploy"
        endpoint        = ""
        lock_table      = "tmhs-locks-dev"
        region          = "us-east-1"
        state_bucket    = "tmhs-state-dev-222222222222"
      }
      infra = {
        account_id      = "111111111111"
        cluster_name    = "tmhs-eks-infra"
        deploy_role_arn = "arn:aws:iam::111111111111:role/tmhs-deploy"
        endpoint        = ""
        lock_table      = "tmhs-locks-infra"
        region          = "us-east-1"
        state_bucket    = "tmhs-state-infra-111111111111"
      }
      prd = {
        account_id      = "333333333333"
        cluster_name    = "tmhs-eks-prd"
        deploy_role_arn = "arn:aws:iam::333333333333:role/tmhs-deploy"
        endpoint        = ""
        lock_table      = "tmhs-locks-prd"
        region          = "us-east-1"
        state_bucket    = "tmhs-state-prd-333333333333"
      }
    }
    type = any
  }
}
