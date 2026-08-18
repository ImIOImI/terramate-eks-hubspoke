// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

provider "helm" {
  kubernetes = {
    host                   = var.cluster_endpoint
    cluster_ca_certificate = base64decode(var.cluster_ca)
    client_certificate     = file("../../../../../.ministack/tmhs-eks-ci.crt")
    client_key             = file("../../../../../.ministack/tmhs-eks-ci.key")
  }
}
