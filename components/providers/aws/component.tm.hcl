define "component" "metadata" {
  class       = "components/providers/aws"
  version     = "0.1.0"
  name        = "aws"
  description = "AWS provider with region, optional assume_role, and default_tags"
}

define "component" {
  input "account_map" {
    type        = any
    description = "map of env -> account config object"
  }
  input "env" {
    type        = string
    description = "target environment id"
  }
  input "default_tags" {
    type        = map(string)
    description = "tags applied to all resources via default_tags"
    default     = {}
  }
  input "assume_role" {
    type        = bool
    description = "whether to add assume_role block to aws provider"
    default     = true
  }
}
