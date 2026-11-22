# `k8s/` — what ArgoCD deploys

```text
k8s/
├── argo/            ApplicationSets the hub ArgoCD manages from git (app-of-apps)
│   ├── argo-rollouts.yaml   Argo Rollouts controller → every registered spoke
│   └── hello.yaml           k8s/kustomize/<overlay> → every spoke with an overlay
└── kustomize/
    ├── default/     base: hello-world (Deployment) + hello-rollout (canary Rollout)
    ├── dev/         overlay: 1 / 2 replicas, blue, 10s canary pause
    └── prd/         overlay: 2 / 3 replicas, green, 30s canary pause
```

**How it gets there.** Tofu installs ArgoCD on the hub and one root
Application pointing at `k8s/argo` (`components/argocd-hub`, `demo_apps = true`,
currently on for the local `ci-hub`). ArgoCD reconciles everything else in this
folder itself.

**Which overlay a spoke gets.** Each spoke's ArgoCD cluster secret carries an
`overlay` label (`k8s_overlay` in `_scaffold-cluster.tm.yml`, default: the env id),
and `hello.yaml` deploys `k8s/kustomize/<overlay>`. Locally, `ci-dev` → `dev` and
`ci-prd` → `prd`.

**Testing a branch.** ArgoCD reads this folder from git, at `main` by default.
Push your branch and run `TF_VAR_demo_apps_revision=<branch> make ci-apply`; the
root Application and every ApplicationSet labelled `tmhs.io/revision: root`
follow that revision.

**Watching a canary.** Change the Rollout image colour in an overlay (e.g.
`argoproj/rollouts-demo:blue` → `yellow` in `dev/kustomization.yaml`) and push. The
spoke's Rollout pauses at 50% before promoting.

Preview an overlay locally with `kubectl kustomize k8s/kustomize/dev`.
