// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

input "vpc_id" {
  backend       = "default"
  from_stack_id = "25cbafe4-f84c-42cf-8b9f-0f7a0537c7c7"
  mock          = "vpc-00000000000000000"
  value         = outputs.vpc_id.value
}
input "private_subnet_ids" {
  backend       = "default"
  from_stack_id = "25cbafe4-f84c-42cf-8b9f-0f7a0537c7c7"
  mock = [
    "subnet-00000000000000000",
    "subnet-00000000000000001",
  ]
  value = outputs.private_subnet_ids.value
}
