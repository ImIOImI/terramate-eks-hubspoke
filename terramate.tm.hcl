terramate {
  config {
    git {
      default_remote = "origin"
      default_branch = "main"
    }
    telemetry { enabled = false }
    experiments = ["outputs-sharing"]
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
  description = "Local MiniStack-backed hub (ArgoCD) for testing the stack chain without AWS; a future ci-spoke registers against it"
}
