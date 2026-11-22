// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

define "bundle" {
  input "providers_map" {
    default = {
      aws = {
        source  = "hashicorp/aws"
        version = "~> 6.52"
      }
      docker = {
        source  = "kreuzwerker/docker"
        version = "~> 4.7"
      }
      helm = {
        source  = "hashicorp/helm"
        version = "~> 3.0"
      }
      kubernetes = {
        source  = "hashicorp/kubernetes"
        version = "~> 2.38"
      }
      tls = {
        source  = "hashicorp/tls"
        version = "~> 4.0"
      }
    }
    type = any
  }
}
