// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

terraform {
  required_version = "1.11.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38"
    }
  }
  backend "s3" {
    bucket         = "tmhs-state-prd-333333333333"
    dynamodb_table = "tmhs-locks-prd"
    encrypt        = true
    key            = "stacks/by-id/92d3dd73-20a6-496f-a687-31c58983070d/terraform.tfstate"
    region         = "us-east-1"
    assume_role {
      role_arn = "arn:aws:iam::333333333333:role/tmhs-deploy"
    }
  }
}
