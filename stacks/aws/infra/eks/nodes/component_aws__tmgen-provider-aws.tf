// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

provider "aws" {
  region = "us-east-1"
  assume_role {
    role_arn = "arn:aws:iam::111111111111:role/tmhs-deploy"
  }
  default_tags {
    tags = {
      Env     = "infra"
      Project = "terramate-eks-hubspoke"
    }
  }
}
