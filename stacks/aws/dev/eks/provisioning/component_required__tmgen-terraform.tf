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
    bucket         = "tmhs-state-dev-222222222222"
    dynamodb_table = "tmhs-locks-dev"
    encrypt        = true
    key            = "stacks/by-id/dev-eks-provisioning/terraform.tfstate"
    region         = "us-east-1"
    assume_role {
      role_arn = "arn:aws:iam::222222222222:role/tmhs-deploy"
    }
  }
}
