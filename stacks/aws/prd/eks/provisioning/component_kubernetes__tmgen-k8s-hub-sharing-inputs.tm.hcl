// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

input "hub_cluster_endpoint" {
  backend       = "default"
  from_stack_id = "bc7799df-a6e7-4eff-af43-4bba3bcca064"
  mock          = "https://hub-mock.eks.example.com"
  value         = outputs.cluster_endpoint.value
}
input "hub_cluster_ca" {
  backend       = "default"
  from_stack_id = "bc7799df-a6e7-4eff-af43-4bba3bcca064"
  mock          = "aHViLW1vY2stY2EtZGF0YQ=="
  value         = outputs.cluster_ca.value
}
