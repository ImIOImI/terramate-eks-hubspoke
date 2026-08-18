// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

variable "vpc_id" {
  type = any
}
variable "private_subnet_ids" {
  type = any
}
output "cluster_service_cidr" {
  value = module.eks.cluster_service_cidr
}
output "cluster_name" {
  value = module.eks.cluster_name
}
output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}
output "cluster_ca" {
  value = module.eks.cluster_certificate_authority_data
}
output "oidc_issuer" {
  value = module.eks.cluster_oidc_issuer_url
}
