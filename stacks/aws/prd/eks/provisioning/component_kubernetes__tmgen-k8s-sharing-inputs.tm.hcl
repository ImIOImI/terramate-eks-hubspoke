// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

input "cluster_endpoint" {
  backend       = "default"
  from_stack_id = "4a4924ee-b872-496e-bb0d-d0e63dea8ed2"
  mock          = "https://mock.eks.example.com"
  value         = outputs.cluster_endpoint.value
}
input "cluster_ca" {
  backend       = "default"
  from_stack_id = "4a4924ee-b872-496e-bb0d-d0e63dea8ed2"
  mock          = "bW9jay1jYS1kYXRh"
  value         = outputs.cluster_ca.value
}
