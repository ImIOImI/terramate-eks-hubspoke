terraform {
  required_version = ">= 1.11.0"
}
language {
  experiments = [symbol_libraries]
}
symbols "net" {
  source = "../../lib/net"
}

variable "cluster_name" { type = string }
variable "region" { type = string }
variable "vpc_cidr" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}

# Subnet/AZ math via the net symbol library (was tm_cidrsubnet).
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = symbols::net::azs(var.region)
  private_subnets = symbols::net::private_subnets(var.vpc_cidr)
  public_subnets  = symbols::net::public_subnets(var.vpc_cidr)

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags  = { "kubernetes.io/role/elb" = 1 }
  private_subnet_tags = { "kubernetes.io/role/internal-elb" = 1 }
  tags                = var.tags
}

output "vpc_id" { value = module.vpc.vpc_id }
output "private_subnet_ids" { value = module.vpc.private_subnets }
