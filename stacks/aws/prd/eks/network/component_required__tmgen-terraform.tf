// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

terraform {
  required_version = "1.13.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.52"
    }
  }
  backend "s3" {
    bucket         = "tmhs-state-prd-333333333333"
    dynamodb_table = "tmhs-locks-prd"
    encrypt        = true
    key            = "stacks/by-id/prd-eks-network/terraform.tfstate"
    region         = "us-east-1"
    assume_role {
      role_arn = "arn:aws:iam::333333333333:role/tmhs-deploy"
    }
  }
}
