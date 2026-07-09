generate_hcl "_tmgen-network.tf" {
  content {
    module "vpc" {
      source  = component.input.terraform_modules.value.vpc.source
      version = component.input.terraform_modules.value.vpc.version

      name = "${component.input.cluster_name.value}-vpc"
      cidr = component.input.vpc_cidr.value

      azs             = ["${component.input.region.value}a", "${component.input.region.value}b"]
      private_subnets = [tm_cidrsubnet(component.input.vpc_cidr.value, 4, 0), tm_cidrsubnet(component.input.vpc_cidr.value, 4, 1)]
      public_subnets  = [tm_cidrsubnet(component.input.vpc_cidr.value, 4, 8), tm_cidrsubnet(component.input.vpc_cidr.value, 4, 9)]

      enable_nat_gateway   = true
      single_nat_gateway   = true
      enable_dns_hostnames = true

      public_subnet_tags  = { "kubernetes.io/role/elb" = 1 }
      private_subnet_tags = { "kubernetes.io/role/internal-elb" = 1 }
    }
  }
}

generate_hcl "_tmgen-sharing-outputs.tm.hcl" {
  content {
    output "vpc_id" {
      backend = "default"
      value   = module.vpc.vpc_id
    }
    output "private_subnet_ids" {
      backend = "default"
      value   = module.vpc.private_subnets
    }
  }
}
