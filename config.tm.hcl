globals {
  project_prefix = "tmhs"
  tofu_version   = "1.13.9"
  github_repo    = "ImIOImI/terramate-eks-hubspoke"

  envs = {
    infra = { account_id = "111111111111", region = "us-east-1" }
    dev   = { account_id = "222222222222", region = "us-east-1" }
    prd   = { account_id = "333333333333", region = "us-east-1" }

    # Local-only environment backed by MiniStack (https://ministack.org).
    # `endpoint` is what makes an env local: every component that talks to AWS
    # checks for it and redirects there instead. account_id must be the 12 digits
    # used as the access key -- MiniStack turns that into the account id.
    # `ci-hub` plays the hub role (ArgoCD); `ci-dev` and `ci-prd` register
    # against it as spokes, sharing this one MiniStack endpoint. Nothing keys
    # off the strings, so another local env is just another entry here.
    "ci-hub" = {
      account_id = "000000000099"
      region     = "us-east-1"
      endpoint   = "http://localhost:4566"
    }
    # Local spokes of ci-hub, mirroring dev/prd -> infra. Each is its own
    # MiniStack account (its own access key) on the same endpoint.
    "ci-dev" = {
      account_id = "000000000098"
      region     = "us-east-1"
      endpoint   = "http://localhost:4566"
    }
    "ci-prd" = {
      account_id = "000000000097"
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
      aws        = { source = "hashicorp/aws", version = "~> 6.52" }
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
