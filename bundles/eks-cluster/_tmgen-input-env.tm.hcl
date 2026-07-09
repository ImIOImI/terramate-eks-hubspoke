// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

define "bundle" {
  input "env" {
    default     = "dev"
    description = "Target environment"
    type        = string
    prompt {
      options = [
        "infra",
        "dev",
        "prd",
      ]
      text = "Environment:"
    }
  }
}
