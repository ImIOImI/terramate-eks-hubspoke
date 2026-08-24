define "component" "metadata" {
  class       = "components/symbols-iam"
  version     = "0.1.0"
  name        = "symbols-iam"
  description = "Enables the symbol_libraries experiment and wires the shared /lib/iam symbol library into a stack. Include in every stack that renders IAM policy documents via symbols::iam::*."
}

define "component" {
  input "lib_path" {
    type        = string
    description = "project-root-relative path to the symbol library directory"
    default     = "lib/iam"
  }
}
