// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

provider "kubernetes" {
  client_certificate     = file("../../../../../.ministack/tmhs-eks-ci.crt")
  client_key             = file("../../../../../.ministack/tmhs-eks-ci.key")
  cluster_ca_certificate = base64decode(var.cluster_ca)
  host                   = var.cluster_endpoint
}
