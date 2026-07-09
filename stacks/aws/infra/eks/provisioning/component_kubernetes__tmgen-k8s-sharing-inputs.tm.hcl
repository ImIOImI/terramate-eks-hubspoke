// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

input "cluster_endpoint" {
  backend       = "default"
  from_stack_id = "bc7799df-a6e7-4eff-af43-4bba3bcca064"
  mock          = "https://mock.eks.example.com"
  value         = outputs.cluster_endpoint.value
}
input "cluster_ca" {
  backend       = "default"
  from_stack_id = "bc7799df-a6e7-4eff-af43-4bba3bcca064"
  mock          = "bW9jay1jYS1kYXRh"
  value         = outputs.cluster_ca.value
}
