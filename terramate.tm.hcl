terramate {
  # Tested range: docs/TOOLCHAIN.md. 0.16.x cannot parse the bundle `define` blocks.
  required_version = ">= 0.17.0, < 0.18.0"

  config {
    git {
      default_remote = "origin"
      default_branch = "main"
    }
    telemetry { enabled = false }
    experiments = ["outputs-sharing", "scripts"]
  }
}

environment {
  id          = "infra"
  name        = "Infrastructure Hub"
  description = "Shared infrastructure account: ArgoCD hub cluster, CI entry role"
}

environment {
  id          = "dev"
  name        = "Development"
  description = "Development spoke account"
}

environment {
  id           = "prd"
  name         = "Production"
  description  = "Production spoke account"
  promote_from = "dev"
}

environment {
  id          = "ci-hub"
  name        = "Local CI Hub"
  description = "Local MiniStack-backed hub (ArgoCD) for testing the stack chain without AWS"
}

environment {
  id          = "ci-dev"
  name        = "Local CI Dev"
  description = "Local MiniStack-backed spoke of ci-hub (mirrors dev)"
}

environment {
  id          = "ci-prd"
  name        = "Local CI Prd"
  description = "Local MiniStack-backed spoke of ci-hub (mirrors prd)"
}
