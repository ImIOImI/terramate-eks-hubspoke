globals {
  project_prefix = "tmhs"
  tofu_version   = "1.10.5"
  github_repo    = "ImIOImI/terramate-eks-hubspoke"

  envs = {
    infra = { account_id = "111111111111", region = "us-east-1" }
    dev   = { account_id = "222222222222", region = "us-east-1" }
    prd   = { account_id = "333333333333", region = "us-east-1" }
  }

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
