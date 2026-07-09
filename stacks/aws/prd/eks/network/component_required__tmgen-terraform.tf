// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

terraform {
  required_version = "1.11.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  backend "s3" {
    bucket         = "tmhs-state-prd-333333333333"
    dynamodb_table = "tmhs-locks-prd"
    encrypt        = true
    key            = "stacks/by-id/9970ab7c-f545-422a-892b-39d2ed16f20b/terraform.tfstate"
    region         = "us-east-1"
    assume_role {
      role_arn = "arn:aws:iam::333333333333:role/tmhs-deploy"
    }
  }
}
