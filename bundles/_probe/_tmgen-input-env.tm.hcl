// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

define "bundle" {
  input "env" {
    description = "Target environment"
    options = [
      "infra",
      "dev",
      "prd",
    ]
    prompt = "Environment:"
    type   = string
  }
}
