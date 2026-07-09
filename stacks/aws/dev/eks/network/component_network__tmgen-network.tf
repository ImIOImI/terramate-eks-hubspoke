// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

module "vpc" {
  azs = [
    "us-east-1a",
    "us-east-1b",
  ]
  cidr                 = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_nat_gateway   = true
  name                 = "tmhs-eks-dev-vpc"
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
  private_subnets = [
    "10.0.0.0/20",
    "10.0.16.0/20",
  ]
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }
  public_subnets = [
    "10.0.128.0/20",
    "10.0.144.0/20",
  ]
  single_nat_gateway = true
  source             = "terraform-aws-modules/vpc/aws"
  version            = "6.6.1"
}
