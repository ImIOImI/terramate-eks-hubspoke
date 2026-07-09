// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

provider "aws" {
  region = "us-east-1"
  assume_role {
    role_arn = "arn:aws:iam::333333333333:role/tmhs-deploy"
  }
  default_tags {
    tags = {
      Env     = "prd"
      Project = "terramate-eks-hubspoke"
    }
  }
}
