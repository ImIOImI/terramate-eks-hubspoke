// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

provider "kubernetes" {
  alias                  = "hub"
  cluster_ca_certificate = base64decode(var.hub_cluster_ca)
  host                   = var.hub_cluster_endpoint
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      "tmhs-eks-infra",
      "--role-arn",
      "arn:aws:iam::111111111111:role/tmhs-deploy",
    ]
    command = "aws"
  }
}
