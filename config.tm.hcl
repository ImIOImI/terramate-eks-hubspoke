globals {
  project_prefix = "tmhs"
  tofu_version   = "1.11.5"
  github_repo    = "ImIOImI/terramate-eks-hubspoke"

  envs = {
    infra = { account_id = "111111111111", region = "us-east-1" }
    dev   = { account_id = "222222222222", region = "us-east-1" }
    prd   = { account_id = "333333333333", region = "us-east-1" }

    # Local-only environment backed by MiniStack (https://ministack.org).
    # `endpoint` is what makes an env local: every component that talks to AWS
    # checks for it and redirects there instead. account_id must be the 12 digits
    # used as the access key -- MiniStack turns that into the account id.
    # `ci-hub` plays the hub role (ArgoCD); a future `ci-spoke` would register
    # against it, sharing this one MiniStack endpoint. Nothing keys off the
    # string, so adding that spoke is just another entry here.
    "ci-hub" = {
      account_id = "000000000099"
      region     = "us-east-1"
      endpoint   = "http://localhost:4566"
    }
  }

  # Services this repo touches, redirected to the MiniStack endpoint for local envs.
  ministack_services = [
    "s3", "dynamodb", "iam", "sts", "ec2", "eks", "kms",
    "autoscaling", "elasticloadbalancing", "logs",
  ]

  terraform = {
    providers = {
      aws        = { source = "hashicorp/aws", version = "~> 6.0" }
      kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.38" }
      helm       = { source = "hashicorp/helm", version = "~> 3.0" }
      tls        = { source = "hashicorp/tls", version = "~> 4.0" }
    }
  }

  tags = {
    Project   = "terramate-eks-hubspoke"
    ManagedBy = "opentofu"
  }
}
