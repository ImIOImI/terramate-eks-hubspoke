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
    bucket         = "tmhs-state-infra-111111111111"
    dynamodb_table = "tmhs-locks-infra"
    encrypt        = true
    key            = "stacks/by-id/1345fdff-3d2a-44e2-af1e-2b89829f9927/terraform.tfstate"
    region         = "us-east-1"
    assume_role {
      role_arn = "arn:aws:iam::111111111111:role/tmhs-deploy"
    }
  }
}
