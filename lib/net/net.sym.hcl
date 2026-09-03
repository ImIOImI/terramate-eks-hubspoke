# net — subnet/AZ math (was tm_cidrsubnet in the network component).
# Pure functions; used directly inside the network module.

function "azs" {
  parameter "region" { type = string }
  return = ["${param.region}a", "${param.region}b"]
}
function "private_subnets" {
  parameter "cidr" { type = string }
  return = [cidrsubnet(param.cidr, 4, 0), cidrsubnet(param.cidr, 4, 1)]
}
function "public_subnets" {
  parameter "cidr" { type = string }
  return = [cidrsubnet(param.cidr, 4, 8), cidrsubnet(param.cidr, 4, 9)]
}
