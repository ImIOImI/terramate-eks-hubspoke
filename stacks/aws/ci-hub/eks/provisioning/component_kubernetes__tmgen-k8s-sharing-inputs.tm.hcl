// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

input "cluster_endpoint" {
  backend       = "default"
  from_stack_id = "ci-hub-eks-cluster"
  mock          = "https://mock.eks.example.com"
  value         = outputs.cluster_endpoint.value
}
input "cluster_ca" {
  backend       = "default"
  from_stack_id = "ci-hub-eks-cluster"
  mock          = "bW9jay1jYS1kYXRh"
  value         = outputs.cluster_ca.value
}
