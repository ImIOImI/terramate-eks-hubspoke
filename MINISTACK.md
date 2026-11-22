# Local hub + spokes on MiniStack (`ci-hub`, `ci-dev`, `ci-prd`)

Three local environments mirror the real `infra` → `dev` / `prd` topology on
[MiniStack](https://ministack.org): `ci-hub` runs ArgoCD, and `ci-dev` and `ci-prd`
register with it as spokes. No AWS account, no cost.

```bash
make ci-apply     # ~15 min from cold: all three envs, demo apps, test, then prints the ArgoCD URL
make ci-down      # remove the whole local fabric
```

It is a real end-to-end run, not a plan. MiniStack's `eks:CreateCluster` starts a
**real k3s container** per cluster. The hub's provisioning stack installs ArgoCD
with Helm, each spoke's provisioning stack registers the spoke with that ArgoCD,
and the hub then deploys the demo apps to both spokes **through ArgoCD itself**.

At the end `make ci-apply` prints:

```text
ArgoCD hub (ci-hub): https://localhost:8443   (self-signed certificate)
  user:     admin
  password: <generated>
```

Open it to see both spoke clusters and the six demo Applications. `make ci-argo`
prints it again at any time.

---

## What gets deployed to every spoke

`ci-hub` sets `demo_apps: true` in `_scaffold-cluster.tm.yml`. Its ArgoCD then owns
three ApplicationSets that target **every registered spoke** (any cluster secret
carrying the `env` label; the hub's own in-cluster entry has none):

| ApplicationSet | Source | Proves |
|---|---|---|
| `argo-rollouts` | argo-helm `argo-rollouts` chart | the hub can install a controller + CRDs on a spoke |
| `hello-world` | [`charts/hello-world`](charts/hello-world) — a Deployment of `traefik/whoami` | plain sync + health across clusters |
| `hello-rollout` | [`charts/hello-rollout`](charts/hello-rollout) — a canary `Rollout` of `argoproj/rollouts-demo` | Argo Rollouts progressive delivery (50% → pause → 100%) |

`make ci-test` (part of `make ci-apply`) waits, on the hub, for each spoke's three
Applications to be **Synced** and **Healthy**, then lists what actually landed on
that spoke's own k3s.

**Charts come from git, not your working tree.** ArgoCD clones this repo, at
`main` by default. To test unmerged chart changes, push your branch and run with:

```bash
TF_VAR_demo_apps_revision=<branch> make ci-apply
```

**Watching a canary:** change `color:` in `charts/hello-rollout/values.yaml` (for
example `blue` → `yellow`), push, and the Rollout on each spoke pauses at 50% for
30 s before promoting. Tested by pushing a yellow commit: both spokes went
`Paused (step 1)` → `Healthy` on the new image.

---

## How it is orchestrated: Terramate Scripts

There is no tier loop in bash. [`scripts.tm.hcl`](scripts.tm.hcl) defines a
`deploy` script, and `make ci-apply` is three Terramate commands:

```bash
terramate script run --tags local deploy   # every local stack, in stack-graph order
terramate script run ci test               # demo-app checks (spoke provisioning stacks only)
terramate script run ci argo               # print the hub URL + login
```

- **Ordering comes from the stack graph.** Terramate runs every job of a script for
  one stack before moving to the next, following the `after` edges the bundle
  already declares: bootstrap → network → cluster → nodes → provisioning, and
  spoke provisioning after hub provisioning. Per-stack init + apply is exactly what
  outputs-sharing needs (a producer is applied before any consumer is initialised).
- **Local-only steps are chosen per stack from its tags.** A `local` bootstrap
  stack also starts MiniStack (`make/ci-up.sh`), and a `local` cluster stack also
  pulls its k3s certs + container IP into `.ministack/` (`make/ci-kubeconfig.sh`)
  right after it applies.
- **`ci test` and `ci argo` exist only where they make sense.** The argocd-spoke and
  argocd-hub components *generate* those script blocks into the local
  provisioning stacks, so `terramate script run ci test` reaches exactly the two
  spokes, and `terramate script list` shows where each is defined.

The same `deploy` script drives real environments: `make apply ENV=dev` is
`terramate script run --tags env-dev deploy`.

---

## How an environment becomes local

`config.tm.hcl` gives each local env an `endpoint`:

```hcl
"ci-hub" = { account_id = "000000000099", region = "us-east-1", endpoint = "http://localhost:4566" }
"ci-dev" = { account_id = "000000000098", region = "us-east-1", endpoint = "http://localhost:4566" }
"ci-prd" = { account_id = "000000000097", region = "us-east-1", endpoint = "http://localhost:4566" }
```

That single field is the switch. `objects/inputs/account-map.tm.hcl` surfaces it
(`""` for real environments), and each component checks it. Nothing keys off the
env names, so another local env is just another `endpoint` entry plus a scaffold
entry.

MiniStack turns a **12-digit access key into the account id**, which is why
`account_id` and the access key are the same value. That makes the three local
envs three separate accounts on one endpoint. Each cluster gets its own k3s
container and host port (16443, 16444, 16445, …).

Components emit local variants as *separate* `generate_hcl` blocks with opposite
conditions rather than conditionals inside the shared block, so the real-AWS
output stays byte-identical.

---

## What differs from a real environment

Each divergence is a MiniStack gap, not a preference.

| # | Divergence | Why |
|---|---|---|
| 1 | **Kubernetes auth uses a client certificate, not exec-auth** | `aws eks get-token` returns a well-formed `ExecCredential`, but MiniStack's k3s has no aws-iam-authenticator webhook and answers `401`. `make/ci-kubeconfig.sh` extracts each k3s admin cert into `.ministack/`. |
| 2 | **Spokes register with ArgoCD by client cert + container IP** | The real cluster secret uses `awsAuthConfig` (an EKS token: 401 again) and the EKS endpoint. MiniStack reports `https://localhost:<port>`, which only resolves on the host, not inside the hub's ArgoCD pod. The local secret uses `tlsClientConfig` with the spoke's k3s cert, and its Docker bridge IP (k3s's serving cert includes that IP). |
| 3 | **The ArgoCD UI is published through a proxy container** | MiniStack's k3s publishes only its API port, and under Docker Desktop container IPs are not routable from the host. The local hub adds a NodePort service and a socat container (tofu-managed, `kreuzwerker/docker` provider) on `127.0.0.1:8443`. |
| 4 | `enable_irsa = false` | MiniStack serves the cluster's OIDC issuer over `http://`; the module's `data.tls_certificate` refuses any scheme but `https`/`tls`. |
| 5 | `use_latest_ami_release_version = false` | The lookup reads `/aws/service/eks/optimized-ami/...` from SSM's *public* parameter store, which MiniStack does not carry. |
| 6 | No `aws_eks_pod_identity_association` | `CreatePodIdentityAssociation` returns `No route`. The binding would be inert against k3s anyway. |
| 7 | No `assume_role` on provider or backend | MiniStack authenticates purely on the access key. There is no role to assume. |

**Divergences 1 and 2 are the ones that matter.** A green local run does not prove
exec-auth or the hub controller's cross-account role assumption into the spokes.
It does prove the state/backend/sharing/ordering machinery, the hub → spoke
registration secrets, hub → spoke networking, ApplicationSet fan-out, sync,
health, and Argo Rollouts canaries, all against real Kubernetes API servers.

Also note k3s reports **v1.31.4** even though `describe-cluster` echoes back the
requested `1.33`, so add-on versions pinned for 1.33 are not truly exercised.

---

## Requirements

- **Docker, with the socket mounted.** `make ci-up` does this. Without
  `-v /var/run/docker.sock:/var/run/docker.sock`, EKS is a control-plane stub and
  no k3s container ever appears; the cluster stack "succeeds" but nothing runs.
- Ports `4566` (MiniStack), `16443`–`16445` (one k3s API per cluster), and `8443`
  (the hub ArgoCD UI).
- Internet access from the k3s clusters: ArgoCD pulls charts from GitHub and
  argo-helm, and the spokes pull the demo images from Docker Hub.

Run just the hub with `make ci-hub-apply` (about 4 minutes); it skips the spokes and
the demo-app test.

---

## CI safety

Every local stack carries a `local` tag, and `preview.yml` filters with
`--tags eks --no-tags local`. Without that, GitHub Actions would try to plan
`localhost:4566` stacks against real AWS.

```console
$ terramate list --tags eks | wc -l                   # 24
$ terramate list --tags eks --no-tags local | wc -l   # 12  <- what CI plans
```

`deploy.yml` was already safe: it selects explicit `env-<id>:eks` tags.

---

## Two fixes this surfaced in the real environments

Making the node group work locally required pinning things that were floating:

- **`kubernetes_version` is now passed to the node group.** It previously fell
  through to `data.aws_eks_cluster_versions[0]` — the newest standard-support
  version — which could drift *ahead of* the 1.33 control plane. Now both are
  pinned to the same `kubernetes_version` bundle input.
- **`enable_irsa` and `use_latest_ami_release_version` are now explicit.** Both
  match the upstream defaults (`true`), so real environments are unchanged.
