sharing_backend "default" {
  type     = terraform
  command  = ["tofu", "output", "-json"]
  filename = "_tmgen-sharing.tf"
}
