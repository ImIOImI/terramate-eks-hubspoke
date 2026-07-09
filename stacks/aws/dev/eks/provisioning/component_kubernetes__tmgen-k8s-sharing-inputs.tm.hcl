// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

input "cluster_endpoint" {
  backend       = "default"
  from_stack_id = "cfb032a8-3d93-4ead-8d5b-0d35f4fd3596"
  mock          = "https://mock.eks.example.com"
  value         = outputs.cluster_endpoint.value
}
input "cluster_ca" {
  backend       = "default"
  from_stack_id = "cfb032a8-3d93-4ead-8d5b-0d35f4fd3596"
  mock          = "bW9jay1jYS1kYXRh"
  value         = outputs.cluster_ca.value
}
