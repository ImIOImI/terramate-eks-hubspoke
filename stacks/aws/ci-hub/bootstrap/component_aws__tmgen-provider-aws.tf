// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

provider "aws" {
  access_key                  = "000000000099"
  region                      = "us-east-1"
  s3_use_path_style           = true
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  endpoints {
    autoscaling          = "http://localhost:4566"
    dynamodb             = "http://localhost:4566"
    ec2                  = "http://localhost:4566"
    eks                  = "http://localhost:4566"
    elasticloadbalancing = "http://localhost:4566"
    iam                  = "http://localhost:4566"
    kms                  = "http://localhost:4566"
    logs                 = "http://localhost:4566"
    s3                   = "http://localhost:4566"
    sts                  = "http://localhost:4566"
  }
  default_tags {
    tags = {
      Env     = "ci-hub"
      Project = "terramate-eks-hubspoke"
    }
  }
}
