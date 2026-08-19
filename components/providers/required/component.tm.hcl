define "component" "metadata" {
  class       = "components/providers/required"
  version     = "0.1.0"
  name        = "required"
  description = "terraform block: version pins + per-account S3 backend (tpe pattern)"
}

define "component" {
  input "providers" {
    type        = any
    description = "map of provider name -> { source, version }"
  }
  input "tofu_version" {
    type        = string
    description = "exact OpenTofu version to pin"
  }
  input "account_map" {
    type        = any
    description = "map of env -> account config object"
  }
  input "env" {
    type        = string
    description = "target environment id"
  }
  input "state_backend" {
    type        = string
    description = "s3 or local"
    default     = "s3"
  }
  input "backend_assume_role" {
    type        = bool
    description = "whether to add assume_role block to s3 backend"
    default     = true
  }
  input "deploy_role_arn" {
    type        = string
    description = "explicit deploy-role ARN to assume; empty = derive tmhs-deploy from the account map"
    default     = ""
  }
}
