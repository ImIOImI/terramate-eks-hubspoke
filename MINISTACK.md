# The `ci-hub` environment (MiniStack)

`ci-hub` is a fourth environment that runs the entire stack chain — bootstrap →
network → cluster → nodes → provisioning — against
[MiniStack](https://ministack.org) on your laptop. No AWS account, no cost. It
plays the hub role (ArgoCD); a future `ci-spoke` would register against it inside
the same MiniStack fabric.

```bash
make ci-hub-apply # ~3 minutes from cold
make ci-down      # remove the whole local fabric
```

It is a real end-to-end run, not a plan: MiniStack's `eks:CreateCluster` starts a
**real k3s container**, and the provisioning stack installs ArgoCD into it via
Helm. All seven ArgoCD pods come up `Running`.

---

## How an environment becomes local

`config.tm.hcl` gives `ci-hub` an `endpoint`:

```hcl
"ci-hub" = {
  account_id = "000000000099"
  region     = "us-east-1"
  endpoint   = "http://localhost:4566"
}
```

That single field is the switch. `objects/inputs/account-map.tm.hcl` surfaces it
(`""` for real environments), and each component checks it. Nothing keys off the
string `"ci-hub"`, so a second local environment (e.g. `ci-spoke`) is just
another `endpoint` entry.

MiniStack turns a **12-digit access key into the account id**, which is why
`account_id` and the access key are the same value.

Components emit local variants as *separate* `generate_hcl` blocks with opposite
conditions rather than conditionals inside the shared block, so the real-AWS
output stays byte-identical.

---

## What differs from a real environment

Five deliberate divergences. Each is a MiniStack gap, not a preference.

| # | Divergence | Why |
|---|---|---|
| 1 | **Kubernetes auth uses a client certificate, not exec-auth** | `aws eks get-token` returns a well-formed `ExecCredential`, but MiniStack's k3s has no aws-iam-authenticator webhook and answers `401`. `make ci-kubeconfig` extracts k3s's admin cert into `.ministack/`. |
| 2 | `enable_irsa = false` | MiniStack serves the cluster's OIDC issuer over `http://`; the module's `data.tls_certificate` refuses any scheme but `https`/`tls`. |
| 3 | `use_latest_ami_release_version = false` | The lookup reads `/aws/service/eks/optimized-ami/...` from SSM's *public* parameter store, which MiniStack does not carry. |
| 4 | No `aws_eks_pod_identity_association` | `CreatePodIdentityAssociation` returns `No route`. The binding would be inert against k3s anyway. |
| 5 | No `assume_role` on provider or backend | MiniStack authenticates purely on the access key. There is no role to assume. |

**Divergence 1 is the one that matters.** The auth path `ci-hub` exercises is not
the one production uses, so a green `ci-hub` run does not prove exec-auth works. It proves
the state/backend/sharing/ordering machinery works, and that the Kubernetes and
Helm resources apply against a real API server.

Also note k3s reports **v1.31.4** even though `describe-cluster` echoes back the
requested `1.33`, so add-on versions pinned for 1.33 are not truly exercised.

---

## Why `ci-hub-apply` goes tier by tier

Outputs-sharing cannot resolve a producer's outputs until that producer is
applied, so `tofu init` across the whole environment fails up front with
`This object does not have an attribute named "vpc_id"`. Each tier is initialized
and applied before the next.

`make ci-kubeconfig` must land **between cluster and nodes** — it reads certs out
of the k3s container that the cluster stack creates.

---

## Requirements

- **Docker, with the socket mounted.** `make ci-up` does this. Without
  `-v /var/run/docker.sock:/var/run/docker.sock`, EKS is a control-plane stub and
  no k3s container ever appears — the cluster stack "succeeds" but nothing runs.
- Ports `4566` (MiniStack) and `16443` (k3s API).

---

## CI safety

`ci-hub` stacks carry a `local` tag, and `preview.yml` filters with
`--tags eks --no-tags local`. Without that, GitHub Actions would try to plan
`localhost:4566` stacks against real AWS.

```console
$ terramate list --tags eks | wc -l              # 16
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
