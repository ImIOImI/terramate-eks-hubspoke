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
    access_key     = "000000000099"
    bucket         = "tmhs-state-ci-000000000099"
    dynamodb_table = "tmhs-locks-ci"
    encrypt        = true
    endpoints = {
      dynamodb = "http://localhost:4566"
      iam      = "http://localhost:4566"
      s3       = "http://localhost:4566"
      sts      = "http://localhost:4566"
    }
    key                         = "stacks/by-id/ci-eks-network/terraform.tfstate"
    region                      = "us-east-1"
    secret_key                  = "test"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
    use_path_style              = true
  }
}
