// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

input "private_subnet_ids" {
  backend       = "default"
  from_stack_id = "ci-eks-network"
  mock = [
    "subnet-00000000000000000",
    "subnet-00000000000000001",
  ]
  value = outputs.private_subnet_ids.value
}
input "cluster_service_cidr" {
  backend       = "default"
  from_stack_id = "ci-eks-cluster"
  mock          = "172.20.0.0/16"
  value         = outputs.cluster_service_cidr.value
}
