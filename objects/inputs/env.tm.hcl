generate_hcl "_tmgen-input-env.tm.hcl" {
  condition = tm_alltrue([
    tm_contains(terramate.stack.tags, "default"),
    !tm_contains(terramate.stack.tags, "nogen"),
  ])
  content {
    define "bundle" {
      input "env" {
        type        = string
        description = "Target environment"
        default     = "dev"
        # unused by bundles (they read bundle.environment.id); default avoids a required-input error
        prompt {
          text    = "Environment:"
          options = ["infra", "dev", "prd"]
        }
      }
    }
  }
}
