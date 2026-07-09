define "component" "metadata" {
  class       = "components/network"
  version     = "0.1.0"
  name        = "network"
  description = "VPC + subnets for one EKS cluster (single NAT)"
}

define "component" {
  input "terraform_modules" {
    type        = any
    description = "map of module name -> {source, version}; expects .vpc.source and .vpc.version"
  }
  input "cluster_name" {
    type        = string
    description = "EKS cluster name; used to name the VPC"
  }
  input "region" {
    type        = string
    description = "AWS region; used to construct AZ names"
  }
  input "vpc_cidr" {
    type        = string
    description = "CIDR block for the VPC"
    default     = "10.0.0.0/16"
  }
}
