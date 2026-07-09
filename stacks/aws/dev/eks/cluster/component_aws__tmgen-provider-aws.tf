// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

provider "aws" {
  region = "us-east-1"
  assume_role {
    role_arn = "arn:aws:iam::222222222222:role/tmhs-deploy"
  }
  default_tags {
    tags = {
      Env     = "dev"
      Project = "terramate-eks-hubspoke"
    }
  }
}
