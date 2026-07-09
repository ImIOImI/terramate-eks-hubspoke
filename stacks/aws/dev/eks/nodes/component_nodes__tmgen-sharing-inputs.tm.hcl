// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

input "private_subnet_ids" {
  backend       = "default"
  from_stack_id = "25cbafe4-f84c-42cf-8b9f-0f7a0537c7c7"
  mock = [
    "subnet-00000000000000000",
    "subnet-00000000000000001",
  ]
  value = outputs.private_subnet_ids.value
}
input "cluster_service_cidr" {
  backend       = "default"
  from_stack_id = "cfb032a8-3d93-4ead-8d5b-0d35f4fd3596"
  mock          = "172.20.0.0/16"
  value         = outputs.cluster_service_cidr.value
}
