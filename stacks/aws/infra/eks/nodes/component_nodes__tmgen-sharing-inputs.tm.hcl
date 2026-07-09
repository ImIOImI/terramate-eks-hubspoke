// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

input "private_subnet_ids" {
  backend       = "default"
  from_stack_id = "1345fdff-3d2a-44e2-af1e-2b89829f9927"
  mock = [
    "subnet-00000000000000000",
    "subnet-00000000000000001",
  ]
  value = outputs.private_subnet_ids.value
}
input "cluster_service_cidr" {
  backend       = "default"
  from_stack_id = "bc7799df-a6e7-4eff-af43-4bba3bcca064"
  mock          = "172.20.0.0/16"
  value         = outputs.cluster_service_cidr.value
}
