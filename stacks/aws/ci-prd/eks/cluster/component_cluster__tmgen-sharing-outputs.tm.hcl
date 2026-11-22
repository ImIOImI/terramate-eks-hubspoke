// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

output "cluster_service_cidr" {
  backend = "default"
  value   = module.eks.cluster_service_cidr
}
output "cluster_name" {
  backend = "default"
  value   = module.eks.cluster_name
}
output "cluster_endpoint" {
  backend = "default"
  value   = module.eks.cluster_endpoint
}
output "cluster_ca" {
  backend = "default"
  value   = module.eks.cluster_certificate_authority_data
}
output "oidc_issuer" {
  backend = "default"
  value   = module.eks.cluster_oidc_issuer_url
}
