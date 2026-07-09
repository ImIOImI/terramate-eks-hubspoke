generate_hcl "_tmgen-input-project.tm.hcl" {
  condition = tm_alltrue([
    tm_contains(terramate.stack.tags, "default"),
    !tm_contains(terramate.stack.tags, "nogen"),
  ])
  content {
    define "bundle" {
      input "project_prefix" {
        type    = string
        default = global.project_prefix
      }

      input "github_repo" {
        type    = string
        default = global.github_repo
      }

      input "tofu_version" {
        type    = string
        default = global.tofu_version
      }
    }
  }
}
