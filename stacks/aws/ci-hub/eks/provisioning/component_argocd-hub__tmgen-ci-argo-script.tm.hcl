// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

script "ci" "argo" {
  description = "Print the hub ArgoCD URL + admin credentials"
  job {
    commands = [
      [
        "echo",
        "ArgoCD hub (ci-hub) -- user: admin",
      ],
      [
        "tofu",
        "output",
        "-raw",
        "argocd_url",
      ],
      [
        "echo",
        "",
      ],
      [
        "tofu",
        "output",
        "-raw",
        "argocd_admin_password",
      ],
      [
        "echo",
        "",
      ],
    ]
  }
}
