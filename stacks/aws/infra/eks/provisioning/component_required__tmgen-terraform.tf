// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

terraform {
  required_version = "1.11.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38"
    }
  }
  backend "s3" {
    bucket         = "tmhs-state-infra-111111111111"
    dynamodb_table = "tmhs-locks-infra"
    encrypt        = true
    key            = "stacks/by-id/7a428667-deef-4310-90c0-2751f419feb1/terraform.tfstate"
    region         = "us-east-1"
    assume_role {
      role_arn = "arn:aws:iam::111111111111:role/tmhs-deploy"
    }
  }
}
