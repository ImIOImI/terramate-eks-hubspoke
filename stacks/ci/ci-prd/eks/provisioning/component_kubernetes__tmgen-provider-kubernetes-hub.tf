// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

provider "kubernetes" {
  alias                  = "hub"
  client_certificate     = file("../../../../../.ministack/tmhs-eks-ci-hub.crt")
  client_key             = file("../../../../../.ministack/tmhs-eks-ci-hub.key")
  cluster_ca_certificate = base64decode(var.hub_cluster_ca)
  host                   = var.hub_cluster_endpoint
}
