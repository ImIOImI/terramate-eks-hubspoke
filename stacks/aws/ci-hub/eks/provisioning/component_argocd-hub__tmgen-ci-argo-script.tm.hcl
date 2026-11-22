// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

script "ci" "argo" {
  description = "Print the hub ArgoCD URL + admin credentials"
  job {
    commands = [
      [
        "tofu",
        "output",
        "-raw",
        "argocd_login",
      ],
    ]
  }
}
