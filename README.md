# terramate-eks-hubspoke

[![preview](https://github.com/ImIOImI/terramate-eks-hubspoke/actions/workflows/preview.yml/badge.svg)](https://github.com/ImIOImI/terramate-eks-hubspoke/actions/workflows/preview.yml)

> **Cost warning — read before you apply.**
> This demo spins up **3 EKS control planes** (~$0.10/hr each), **3 NAT gateways**,
> and **6 × t3.large nodes** ≈ **$600+/mo** left running.
> Tear down promptly — see the [Teardown](#teardown) section at the end of this document.

A complete, self-sufficient showcase of the **bundle approach** to standing up EKS clusters
with [Terramate](https://terramate.io) and [OpenTofu](https://opentofu.org):

- An **ArgoCD hub** cluster in an `infra` account
- **Two spoke** clusters (`dev` and `prd`) registered to the hub
- One git repo, full CI, zero org-specific identifiers — clone, fill in account IDs, apply

The `prd` environment sets `promote_from = "dev"`, so a dependency upgrade
(e.g. a CoreDNS version bump) can be tested in `dev` first and promoted to `prd`
by moving the pin up — the same `promote_from` rail carries it.

---

## Table of contents

1. [What this is — five layers](#what-this-is--five-layers)
2. [Repo tour](#repo-tour)
3. [Prerequisites](#prerequisites) — or skip AWS entirely with [MINISTACK.md](MINISTACK.md)
4. [Deploy walkthrough](#deploy-walkthrough) — see also [BOOTSTRAPPING.md](BOOTSTRAPPING.md)
5. [How a change promotes](#how-a-change-promotes)
6. [Pinning policy](#pinning-policy)
7. [Teardown](#teardown)
8. [Production deltas](#production-deltas)
9. [Caveats](#caveats)

---

## What this is — five layers

Terramate's bundle framework lets you express a whole cluster as a single YAML file
and fan it out across environments automatically. The repo is organized in five layers
that compose top-to-bottom:

```text
objects/                     # shared input definitions; backend + aws provider generators
components/                  # network, eks-cluster, eks-nodes, argocd-hub, argocd-spoke, bootstrap
bundles/                     # eks-cluster/ — assembles components into the full per-account tree
_scaffold-cluster.tm.yml     # BundleInstance at the repo root, fanning out via environments
stacks/                      # generated only — never hand-edited
```

**The model:** each `_scaffold-*.tm.yml` at the repo root is a `BundleInstance` — the single hand-written
instance declaration that tells Terramate which bundle to instantiate and what inputs to pass.
The `environments:` map in that file fans the bundle out into one set of stacks per environment,
with per-environment input overrides.  The `stacks/` directory is the generated output of
`make generate` and is committed so CI never needs to run generation.

```text
_scaffold-cluster.tm.yml ─── eks-cluster bundle ──► stacks/aws/<env>/bootstrap
                                                ──► stacks/aws/<env>/eks/{network,cluster,nodes,provisioning}
                                                    (for env in infra, dev, prd, ci-hub)
```

Within each cluster, stacks run in dependency order automatically:
`network → cluster → nodes → provisioning`.
Spoke `provisioning` additionally runs _after_ the infra `provisioning` (hub ArgoCD must
exist before spokes register).

Environments are defined in `terramate.tm.hcl`:

```hcl
environment { id = "infra"  name = "Infrastructure Hub" }
environment { id = "dev"    name = "Development" }
environment { id = "prd"    name = "Production"           promote_from = "dev" }
```

---

## Repo tour

| Layer | Directory | What lives here |
|---|---|---|
| Objects | `objects/` | Shared input schemas; generates backend HCL + AWS provider blocks |
| Components | `components/` | `network`, `eks-cluster`, `eks-nodes`, `eks-core-addons`, `argocd-hub`, `argocd-spoke`, `bootstrap`, `providers` |
| Bundles | `bundles/` | `eks-cluster/` — the full per-account tree (bootstrap + eks chain), role=hub or spoke |
| Scaffold | repo root | `_scaffold-cluster.tm.yml` — the only hand-written instance layer |
| Stacks | `stacks/aws/{infra,dev,prd}/` | Generated; never edit |
| CI | `.github/workflows/` | `preview.yml` (PR), `deploy.yml` (merge to main) |
| Local `ci-hub` env | `MINISTACK.md` | Running the whole chain on [MiniStack](https://ministack.org) with no AWS account |
| Bootstrapping | `BOOTSTRAPPING.md` | First-run order: why bootstrap precedes the cluster stacks, derived stack ids |
| Make helpers | `make/` | `stack-ids.sh` (derive ids from scaffolds + bundles), `create-stacks.sh` (`make stacks`) |
| Design | `docs/design.md` | Architecture decisions, layer diagram, pinning table |
| Spike findings | `docs/SPIKE-FINDINGS.md` | Verified Terramate mechanics (environment fan-out, outputs-sharing, run ordering) |

---

## Prerequisites

| Tool | Version | Notes |
|---|---|---|
| OpenTofu | `1.11.5` | Use [tenv](https://github.com/tofuutils/tenv) — it reads the generated `.opentofu-version` |
| Terramate | `>=0.17.1` (GA) | **Not** Catalyst. See install options below. |
| AWS CLI | Any recent | `aws configure` or environment creds |
| `tflint` | `>=0.63.0` | Optional locally; required by CI |
| `trivy` | Any recent | Optional locally; required by CI |

**Terramate GA install** (pick one):

```bash
# Option A — tenv (recommended; same as CI)
tenv terramate install 0.17.1 && tenv terramate use 0.17.1

# Option B — tarball (x86_64 Linux)
VER=0.17.1
curl -fsSL -o /tmp/terramate.tar.gz \
  https://github.com/terramate-io/terramate/releases/download/v${VER}/terramate_${VER}_linux_x86_64.tar.gz
tar -xzf /tmp/terramate.tar.gz -C /usr/local/bin terramate

# Option C — .deb (Ubuntu/Debian CI runners)
VER=0.17.1
curl -fsSL -o /tmp/terramate.deb \
  https://github.com/terramate-io/terramate/releases/download/v${VER}/terramate_${VER}_linux_amd64.deb
sudo dpkg -i /tmp/terramate.deb
```

> Use the **GA release from GitHub**, not the Catalyst APT repo.  The GA binary is all
> you need for this repo; Catalyst is a separate distribution that adds cloud-dashboard
> features and is not required here.

> **No AWS account?** `make ci-hub-apply` runs the entire chain — including a real
> ArgoCD install — against [MiniStack](https://ministack.org) locally. See
> [MINISTACK.md](MINISTACK.md).

**AWS accounts:** you need three AWS accounts: one for `infra` (hub + CI OIDC entry),
one for `dev`, one for `prd`.  If you only have one account, set the same account ID in
all three slots in `config.tm.hcl` — the `envs` map supports repeated IDs; state keys
are per-stack UUID and do not collide.

---

## Deploy walkthrough

> **Order matters and Terramate does not enforce it.** The bootstrap stacks must be
> applied before any cluster stack can even `tofu init`, and `infra` must be
> bootstrapped before `dev`/`prd`. [BOOTSTRAPPING.md](BOOTSTRAPPING.md) explains why,
> with the generated code that proves it. The steps below are the short version.

### Step 0 — Fork and clone

```bash
gh repo fork ImIOImI/terramate-eks-hubspoke --clone
cd terramate-eks-hubspoke
```

### Step 1 — Fill in account IDs and admin ARNs

Edit `config.tm.hcl` — replace the placeholder account IDs with your real ones:

```hcl
envs = {
  infra = { account_id = "111111111111", region = "us-east-1" }
  dev   = { account_id = "222222222222", region = "us-east-1" }
  prd   = { account_id = "333333333333", region = "us-east-1" }
}
```

Bootstrap auto-trusts whoever runs the apply (`data.aws_caller_identity`), so you
usually add nothing here. Only under **AWS SSO** (whose role ARN can't be derived
from the STS session ARN) or to trust extra principals, add them to
`admin_principal_arns` in `_scaffold-cluster.tm.yml`:

```yaml
spec:
  inputs:
    admin_principal_arns:
      - "arn:aws:iam::111111111111:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_Admin_xxxx"
```

### Step 2 — Generate stacks

```bash
make stacks      # seed each stack.tm.hcl with its derived id; no-op on a plain clone
make generate
```

Two passes run automatically (the first pass emits sharing blocks that the second materializes).
If the output is `Nothing to do, generated code is up to date` the committed stacks are already
current — that is expected after a plain clone.

Verify the stack list:

```bash
$ terramate list --tags env-dev:eks
stacks/aws/dev/eks/cluster
stacks/aws/dev/eks/network
stacks/aws/dev/eks/nodes
stacks/aws/dev/eks/provisioning
```

Run order (all stacks):

```bash
$ terramate list --run-order
stacks/aws/infra/bootstrap
stacks/aws/dev/bootstrap
stacks/aws/infra/eks/network
stacks/aws/prd/bootstrap
stacks/aws/dev/eks/network
stacks/aws/infra/eks/cluster
stacks/aws/prd/eks/network
stacks/aws/dev/eks/cluster
stacks/aws/infra/eks/nodes
stacks/aws/prd/eks/cluster
stacks/aws/dev/eks/nodes
stacks/aws/infra/eks/provisioning
stacks/aws/prd/eks/nodes
stacks/aws/dev/eks/provisioning
stacks/aws/prd/eks/provisioning
```

The bootstrap stacks lead because each environment's `network` stack is `after`
its own bootstrap, and the spoke bootstraps are `after` the CI account's. See
[BOOTSTRAPPING.md](BOOTSTRAPPING.md) for why.

> **Note:** `terramate list --run-order` also lists the two `bundles/*` definition stacks first (they carry no `.tf` files and are excluded from CI by the `eks` tag filter).

> **Why ordering lives in bundles, not stack files.** The generated `stack.tm.hcl`
> files contain only an auto-UUID `id` — no `after`, `tags`, or `name`. Terramate
> re-derives ordering and tag filters from the `define bundle stack` blocks at
> graph-computation time.  This means `--run-order` and `--tags` filters require
> `bundles/`, `components/`, and the root `_scaffold-*.tm.yml` files to be present in the checkout — which is
> always true in this monorepo.

### Step 3 — Bootstrap each account (local apply with admin creds)

Bootstrap stacks create the S3 state bucket, DynamoDB lock table, deploy role, and
(infra only) the GitHub OIDC provider and `gha-ci` entry role.  They are applied
locally with admin credentials and are excluded from CI.

**Apply `infra` first** — the `dev` and `prd` deploy roles trust the `gha-ci` role
that only the infra bootstrap creates, and IAM rejects a trust policy naming a
principal that does not exist. The graph knows this order:

```bash
$ terramate list --run-order --tags bootstrap
stacks/aws/infra/bootstrap
stacks/aws/dev/bootstrap
stacks/aws/prd/bootstrap
```

Each stack runs on ambient admin credentials for **its own** account, so apply them
one at a time rather than in a single `terramate run`. Switch credentials (env vars,
`aws configure`, or `--profile`), then:

```bash
cd stacks/aws/infra/bootstrap
tofu init
tofu apply   # review the plan; type 'yes'
cd -
```

Repeat for `stacks/aws/dev/bootstrap` and `stacks/aws/prd/bootstrap` with their
respective account credentials.

### Step 4 — Migrate bootstrap state to S3

After all three bootstrap stacks are applied, the S3 buckets exist and you can migrate
the bootstrap state into them.

Edit `_scaffold-cluster.tm.yml`, flip `state_backend`:

```yaml
spec:
  inputs:
    state_backend: s3    # was: local
```

Regenerate:

```bash
make generate
```

For each bootstrap stack, migrate:

```bash
cd stacks/aws/infra/bootstrap
tofu init -migrate-state    # answers 'yes' when prompted
cd -

cd stacks/aws/dev/bootstrap
tofu init -migrate-state
cd -

cd stacks/aws/prd/bootstrap
tofu init -migrate-state
cd -
```

Bootstrap stacks are now managed remotely.  CI never touches them; they are excluded
by the `--tags eks` filter used in CI.

### Step 5 — Set the GitHub repository variable

In your fork's GitHub repository **Settings → Secrets and variables → Actions → Variables**,
create a repository variable (not a secret):

| Name | Value |
|---|---|
| `AWS_CI_ROLE_ARN` | ARN of the `tmhs-gha-ci` role created by the infra bootstrap stack |

Find the ARN in the infra bootstrap stack output or in the IAM console
(`tmhs-gha-ci` in the infra account).  The CI workflows gate on this variable:
if it is absent (e.g. a fork without AWS access), the `plan` and `deploy` jobs
are skipped automatically.

### Step 6 — Open a PR to trigger preview

Push a branch with any change (e.g. bump a tag or add a comment) and open a pull request
against `main`.

The `preview.yml` workflow runs two jobs:

1. **static** (no AWS creds required):
   - `terramate generate` drift check
   - `tofu fmt -check`
   - `tflint`
   - `trivy config` scan (suppressions in `.trivyignore`)

2. **plan** (requires `AWS_CI_ROLE_ARN`):
   First, `tofu init` runs on changed stacks:
   ```bash
   terramate run \
     --changed --git-change-base origin/main \
     --tags eks \
     -- tofu init
   ```
   Then, plan with sharing enabled:
   ```bash
   terramate run \
     --changed --git-change-base origin/main \
     --tags eks \
     --enable-sharing --mock-on-fail \
     -- tofu plan -lock=false
   ```
   `--enable-sharing` resolves cross-stack outputs; `--mock-on-fail` satisfies
   greenfield stacks whose producers have never been applied (outputs are mocked
   so the plan succeeds without upstream state).

Merge to `main` triggers `deploy.yml`, which applies `infra` → `dev` → `prd` in
sequence (each job `needs` the previous).

### Step 7 — Local apply (alternative to CI)

You can apply without CI by running `terramate run` directly with the appropriate
account credentials active:

```bash
# Hub (infra account creds)
terramate run --tags env-infra:eks --enable-sharing -- tofu init
terramate run --tags env-infra:eks --enable-sharing -- tofu apply

# Dev spoke (dev account creds) — after infra is fully applied
terramate run --tags env-dev:eks --enable-sharing -- tofu init
terramate run --tags env-dev:eks --enable-sharing -- tofu apply

# Prd spoke (prd account creds) — after dev is fully applied
terramate run --tags env-prd:eks --enable-sharing -- tofu init
terramate run --tags env-prd:eks --enable-sharing -- tofu apply
```

Within each `--tags` group, Terramate executes stacks in graph order automatically:
`network → cluster → nodes → provisioning`, with spoke `provisioning` running after
infra `provisioning`.

### Step 8 — Verify: both spokes visible in ArgoCD

After all three environments are applied, connect to the hub cluster:

```bash
aws eks update-kubeconfig \
  --name tmhs-eks-infra \
  --role-arn arn:aws:iam::111111111111:role/tmhs-deploy \
  --region us-east-1
```

Forward ArgoCD:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Open `https://localhost:8080`.  Log in as `admin` with the initial password:

```bash
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath='{.data.password}' | base64 -d
```

Navigate to **Settings → Clusters**.  You should see:
- `tmhs-eks-dev` — healthy
- `tmhs-eks-prd` — healthy

Registration only — no workloads are deployed to the spokes; the demo endpoint is
the spoke showing healthy in the hub's Argo UI.

---

## How a change promotes

The `promote_from = "dev"` on `prd` means a version bump should be tested in `dev`
first, then promoted to `prd` (or all envs at once via `spec.inputs`).

**Example — bump CoreDNS in dev only:**

1. In `_scaffold-cluster.tm.yml`, add an override under `environments.dev.inputs`:

   ```yaml
   environments:
     dev:
       inputs:
         role: spoke
         hub_env: infra
         addon_versions:
           coredns: "v1.12.5-eksbuild.1"   # bump; all other addons inherit from spec.inputs
         # ... stack_id wiring unchanged ...
   ```

2. Open a PR. The preview plan shows **only dev stacks changed** (infra and prd are
   no-op).

3. Merge → deploy applies `infra` (no-op) → `dev` (CoreDNS bumped) → `prd` (no-op).

4. After validating in dev, move the pin up to `spec.inputs.addon_versions.coredns`
   (or remove the dev override) and open another PR — this time all three envs pick
   up the bump.

The same flow applies to node instance types, module versions, ArgoCD chart version,
or any other scaffold input.

---

## Stack ids

Stack ids are derived from stack paths, not minted as UUIDs:

| Stack path | Id | State key |
|---|---|---|
| `/stacks/aws/dev/eks/network` | `dev-eks-network` | `stacks/by-id/dev-eks-network/terraform.tfstate` |
| `/stacks/aws/infra/bootstrap` | `infra-bootstrap` | `stacks/by-id/infra-bootstrap/terraform.tfstate` |

Terramate only mints a UUID when `stack.tm.hcl` is absent, so `make stacks` seeds
that file first. `make/stack-ids.sh` derives the full stack list by reading the
`environments:` keys from each root `_scaffold-*.tm.yml` and the `metadata.path`
templates from its bundle — nothing is hardcoded.

Because the ids are reproducible, the bundle recomputes them inline for
cross-stack sharing, so there are no `*_stack_id` inputs to hand-wire:

```hcl
network_stack_id     = "${bundle.environment.id}-eks-network"
hub_cluster_stack_id = "${bundle.input.hub_env.value}-eks-cluster"
```

**Adding an environment** is a key in each scaffold plus `make stacks && make generate`.

`make check-ids` (run by `make check` in CI) fails if any `stack.tm.hcl` id has
drifted from its derived value. See
[BOOTSTRAPPING.md](BOOTSTRAPPING.md#stack-ids-are-derived-not-minted).

---

## Pinning policy

Every dependency is pinned in exactly one hand-written place; nothing floats.

| Dependency | Pinned where | Mechanism |
|---|---|---|
| OpenTofu | `config.tm.hcl` → `global.tofu_version` | `required_version` + generated `.opentofu-version` (tenv reads it) |
| Providers (`aws`, `kubernetes`, `helm`, `tls`) | `config.tm.hcl` → `global.terraform.providers` | generated `required_providers` in every stack |
| terraform-aws-modules (`vpc`, `eks`) | `_scaffold-cluster.tm.yml` `spec.inputs.terraform_modules` | components emit `source`/`version` from the input |
| EKS managed add-ons (all five) | `_scaffold-cluster.tm.yml` `spec.inputs.addon_versions` | explicit version on every `aws_eks_addon`; `most_recent = true` is banned |
| ArgoCD Helm chart | `_scaffold-cluster.tm.yml` `spec.inputs.argocd_chart_version` | pinned `version` on the `helm_release` |
| Terramate + OpenTofu in CI | workflow env vars at top of each workflow file | single place to bump |

Per-environment overrides in `_scaffold-cluster.tm.yml` (e.g. a dev-only addon bump)
ride the same `promote_from` rail as everything else — test in dev, promote to prd.

---

## Teardown

**Always read the destroy plan before confirming.**  Never destroy without reading the plan (see [design doc](https://github.com/ImIOImI/terramate-eks-hubspoke/blob/main/docs/design.md)).

Destroy in **reverse graph order** — spokes before hub, within each env from
`provisioning` backward.  Terramate's `--reverse` flag handles this automatically:

```bash
# 1. Prd spoke (prd account creds)
terramate run --reverse --tags env-prd:eks --enable-sharing -- tofu destroy

# 2. Dev spoke (dev account creds)
terramate run --reverse --tags env-dev:eks --enable-sharing -- tofu destroy

# 3. Hub (infra account creds) — last, after both spokes are gone
terramate run --reverse --tags env-infra:eks --enable-sharing -- tofu destroy
```

`--reverse` executes stacks in reverse dependency order:
`provisioning → nodes → cluster → network`.

**Bootstrap teardown** — bootstrap stacks are not tagged `eks` so the above commands
exclude them.  If you want to remove the bootstrap infrastructure too:

1. Flip `state_backend` back to `local` in `_scaffold-cluster.tm.yml` and run
   `make generate`.
2. In each bootstrap stack dir, run `tofu init -migrate-state` to pull state back local.
3. Run `tofu destroy` in each bootstrap dir with that account's admin creds
   (or delete the S3 bucket and DynamoDB table manually from the console).

---

## Production deltas

This repo is a working demo, not a production blueprint.  Before going to production:

| Area | Demo posture | Production recommendation |
|---|---|---|
| Deploy role | `AdministratorAccess` (easy bootstrap) | Least-privilege policy scoped to the resource surface |
| EKS endpoint | Public (`0.0.0.0/0`) | Private or CIDR-restricted; bastion / VPN for exec-auth |
| NAT gateway | Single per env | One per AZ for HA |
| Spoke workloads | Registration only (no ApplicationSet) | Add Argo ApplicationSets selecting by cluster labels |
| Drift detection | None | Schedule `terramate run -- tofu plan` on a cron |
| CI approvals | No GHA environment gates | Add GHA environment protection rules on `prd` deploy |
| Add-on versions | Plausible but unverified | Run `aws eks describe-addon-versions --kubernetes-version 1.33 --addon-name <name>` and adjust before first apply |

---

## Caveats

- **Add-on versions** (`aws-ebs-csi-driver`, `eks-pod-identity-agent`) in
  `_scaffold-cluster.tm.yml` are plausible for Kubernetes 1.33 but have not been
  validated against a live EKS cluster.  Run
  `aws eks describe-addon-versions --kubernetes-version 1.33 --addon-name <name>`
  and adjust the versions before your first apply.

- **Tags and ordering require the full checkout.** The generated `stack.tm.hcl` files
  contain only a stack UUID — no tags, no `after` edges, no name. Terramate re-derives
  these from `bundles/`, `components/`, and the root `_scaffold-*.tm.yml` files at
  graph-computation time.
  Filtering with `--tags env-infra:eks` or running `--run-order` requires the full
  source tree (always true in this repo; relevant if you ever copy just the `stacks/`
  directory somewhere).

- **Spoke provisioning previews** show a meaningful plan only after the hub is applied.
  Before the hub exists, the preview uses `--mock-on-fail` to substitute mocked values
  for cross-stack outputs — the plan succeeds but shows mock values, not real ones.

- **Shared mock footgun.** Mocked cross-stack values are safe when consumed by resource
  arguments or provider config blocks. Do not feed a mocked value into a `data.*` lookup
  (e.g. `data.aws_vpc` filtering by a mocked VPC ID) — it will trigger a live AWS API
  call for a resource that does not exist and fail at plan.

- **Public EKS endpoints** are intentional — exec-auth from CI and from the Kubernetes/
  Helm providers needs to reach the cluster endpoint.  Access is gated by IAM (EKS access
  entries), not by network alone.  Restrict `public_access_cidrs` or go private in
  production.

- **No GHA environment protection** — the deploy jobs apply automatically on merge to
  `main`.  Add [GHA environment approval gates](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)
  on `prd` for real deployments.
