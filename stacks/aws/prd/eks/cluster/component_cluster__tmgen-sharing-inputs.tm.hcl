// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

input "vpc_id" {
  backend       = "default"
  from_stack_id = "9970ab7c-f545-422a-892b-39d2ed16f20b"
  mock          = "vpc-00000000000000000"
  value         = outputs.vpc_id.value
}
input "private_subnet_ids" {
  backend       = "default"
  from_stack_id = "9970ab7c-f545-422a-892b-39d2ed16f20b"
  mock = [
    "subnet-00000000000000000",
    "subnet-00000000000000001",
  ]
  value = outputs.private_subnet_ids.value
}
