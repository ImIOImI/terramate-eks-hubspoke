// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

provider "kubernetes" {
  cluster_ca_certificate = base64decode(var.cluster_ca)
  host                   = var.cluster_endpoint
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      "tmhs-eks-prd",
      "--role-arn",
      "arn:aws:iam::333333333333:role/tmhs-deploy",
    ]
    command = "aws"
  }
}
