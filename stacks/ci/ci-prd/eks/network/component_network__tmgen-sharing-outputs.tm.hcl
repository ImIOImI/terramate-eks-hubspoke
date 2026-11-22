// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

output "vpc_id" {
  backend = "default"
  value   = module.vpc.vpc_id
}
output "private_subnet_ids" {
  backend = "default"
  value   = module.vpc.private_subnets
}
