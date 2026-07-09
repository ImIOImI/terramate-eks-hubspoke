// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

input "private_subnet_ids" {
  backend       = "default"
  from_stack_id = "9970ab7c-f545-422a-892b-39d2ed16f20b"
  mock = [
    "subnet-00000000000000000",
    "subnet-00000000000000001",
  ]
  value = outputs.private_subnet_ids.value
}
input "cluster_service_cidr" {
  backend       = "default"
  from_stack_id = "4a4924ee-b872-496e-bb0d-d0e63dea8ed2"
  mock          = "172.20.0.0/16"
  value         = outputs.cluster_service_cidr.value
}
