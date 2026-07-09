generate_hcl "_tmgen-input-providers-map.tm.hcl" {
  condition = tm_alltrue([
    tm_contains(terramate.stack.tags, "default"),
    !tm_contains(terramate.stack.tags, "nogen"),
  ])
  content {
    define "bundle" {
      input "providers_map" {
        type    = any
        default = global.terraform.providers
      }
    }
  }
}
