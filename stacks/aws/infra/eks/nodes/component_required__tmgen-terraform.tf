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
    bucket         = "tmhs-state-infra-111111111111"
    dynamodb_table = "tmhs-locks-infra"
    encrypt        = true
    key            = "stacks/by-id/infra-eks-nodes/terraform.tfstate"
    region         = "us-east-1"
    assume_role {
      role_arn = "arn:aws:iam::111111111111:role/tmhs-deploy"
    }
  }
}
