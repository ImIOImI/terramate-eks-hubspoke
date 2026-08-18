// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

input "hub_cluster_endpoint" {
  backend       = "default"
  from_stack_id = "infra-eks-cluster"
  mock          = "https://hub-mock.eks.example.com"
  value         = outputs.cluster_endpoint.value
}
input "hub_cluster_ca" {
  backend       = "default"
  from_stack_id = "infra-eks-cluster"
  mock          = "aHViLW1vY2stY2EtZGF0YQ=="
  value         = outputs.cluster_ca.value
}
