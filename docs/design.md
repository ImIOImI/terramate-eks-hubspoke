# Design: `terramate-eks-hubspoke` — public showcase of the bundle approach to EKS clusters

**Date:** 2026-07-09
**Target:** new public repo `ImIOImI/terramate-eks-hubspoke` (user's personal GitHub)
**Status:** approved design, pending implementation plan

## Goal

A monolithic, completely self-sufficient public repo demonstrating the
module/bundle approach to standing up EKS clusters with Terramate + OpenTofu:
an ArgoCD **hub** cluster in an `infra` account and **spoke** clusters in `dev`
and `prd` accounts, registered to the hub. Generalized — zero
organization-specific identifiers. Minimal but actually deployable by
anyone with AWS accounts.

## Requirements (user-stated)

1. Monolithic: one repo, self-sufficient (framework layers + instances + CI).
2. No organization-identifying information; generalized approach.
3. As minimal as possible while viable. Explicitly dropped: org-specific
   integrations (VPN, secrets manager, observability vendor), Karpenter,
   legacy `aws_system_pin`, per-cluster chart pins.
4. Result: an infra ArgoCD hub cluster + dev spoke (+ prd spoke added to give
   `promote_from` meaning).
5. Actually deployable — a user can clone, fill in account IDs, and apply to
   real AWS. (LocalStack was evaluated and rejected: EKS is paid-tier only.)
6. Full CI: GitHub Actions installing minimal deps (tofu, terramate, AWS
   creds via OIDC); a bootstrap bundle initializes each account (OIDC
   provider, roles, state backend).
7. State per account, exactly the `ImIOImI/terramate-provider-example`
   pattern.
8. Uses **Terramate Environments** (environment definitions + per-env
   BundleInstance overrides) to fan the cluster scaffold out per environment.

## Tooling decisions

- **GA Terramate 0.17.1+** (not Catalyst). Verified in
  `/shared/expert-terramate`: GA ≥0.16.0 parses the `define`
  bundles/components framework; Catalyst is APT-only and would block outside
  users. Constraint: avoid `define "bundle" "lets"` only if Catalyst parity is
  ever wanted — not a goal here, GA is the target.
- **OpenTofu** (pin ~1.10.x), `.opentofu-version` generated for tenv.
- terraform-aws-modules for VPC and EKS inside components.
- **Verify early:** the BundleInstance `environments:` YAML fan-out must be
  proven end-to-end on GA 0.17.1 before building on it (docs in this area
  have been wrong; schema probes confirmed only the `define` side).

## Architecture — five layers, one repo

```
terramate.tm.hcl            # project config
environments.tm.hcl         # environment definitions (infra, dev, prd)
config.tm.hcl               # envs map: {account_id, region, role_arn, state bucket/table names}
objects/                    # shared input defs; backend + aws provider generators
components/                 # network, eks-cluster, eks-nodes, argocd-hub, argocd-spoke, bootstrap
bundles/
  account-bootstrap/
  eks-cluster/              # role = "hub" | "spoke" input
scaffold/
  bootstrap.tm.yml          # one BundleInstance, environments: infra/dev/prd
  cluster.tm.yml            # one BundleInstance, environments: infra(hub)/dev(spoke)/prd(spoke)
stacks/                     # generated only — never hand-edited
.github/workflows/          # preview.yml, deploy.yml
README.md                   # showcase narrative + clone-to-running walkthrough
```

## Environments & promotion

```hcl
environment { id = "infra"  name = "Infrastructure Hub"  promote_from = null }
environment { id = "dev"    name = "Development"          promote_from = null }
environment { id = "prd"    name = "Production"           promote_from = "dev" }
```

- `infra` and `dev` are roots; `prd` promotes from `dev` — a cluster change
  reaches prd only after dev succeeds.
- Hub-before-spoke ordering is NOT encoded in promotion; it rides on a
  cross-stack `after` edge (spoke provisioning → hub provisioning).

## Scaffold files (the only hand-written instance layer)

`scaffold/cluster.tm.yml`:

```yaml
apiVersion: terramate.io/cli/v1
kind: BundleInstance
metadata:
  name: eks
spec:
  source: /bundles/eks-cluster
  inputs:
    node_instance_types: ["t3.large"]
    node_scaling: { min: 2, max: 3 }
    terraform_modules:
      vpc: { source: terraform-aws-modules/vpc/aws, version: 6.0.1 }
      eks: { source: terraform-aws-modules/eks/aws, version: 21.0.6 }
    addon_versions:            # explicit — never most_recent=true
      kube-proxy: v1.33.0-eksbuild.2
      vpc-cni: v1.19.6-eksbuild.1
      coredns: v1.12.1-eksbuild.2
      aws-ebs-csi-driver: v1.44.0-eksbuild.1
      eks-pod-identity-agent: v1.3.7-eksbuild.2
    argocd_chart_version: 8.1.2
environments:
  infra: { inputs: { role: hub } }
  dev:   { inputs: { role: spoke, hub_env: infra } }
  prd:   { inputs: { role: spoke, hub_env: infra } }
```

`scaffold/bootstrap.tm.yml`: one `account-bootstrap` instance across all three
environments; `ci_entry: true` overridden in `infra` only.

## Generated stack tree

```
stacks/aws/
├── infra/
│   ├── bootstrap/
│   └── eks/                # role=hub
│       ├── network/        # VPC, subnets, NAT, SGs
│       ├── cluster/        # after ../network — control plane + access
│       │                   #   entries (add-ons deferred)
│       ├── nodes/          # after ../cluster — kube-proxy/vpc-cni add-ons,
│       │                   #   managed node group(s), pod-identity agent
│       └── provisioning/   # after ../nodes — coredns/ebs-csi add-ons,
│                           #   Helm ArgoCD + controller role
├── dev/
│   ├── bootstrap/
│   └── eks/                # role=spoke
│       ├── network/ cluster/ nodes/
│       └── provisioning/   # after ../nodes + /stacks/aws/infra/eks/provisioning
└── prd/                    # identical to dev
```

- Namespacing is flat: `aws/<env>/<instance>`. State is keyed by stack UUID
  (`stacks/by-id/<id>/terraform.tfstate`) so paths are cosmetic.
- Full-run order per cluster: network → cluster → nodes → provisioning.
- `provisioning` is after `nodes` (not just cluster) because ArgoCD pods and
  CoreDNS need schedulable nodes.
- Spoke `cluster/` additionally creates the EKS access entry for the
  spoke-access role.

## State & config (terramate-provider-example pattern, per user's repo)

- Per-account S3 bucket `<prefix>-state-<env>` + per-account DynamoDB lock
  table, living in that env's account.
- Backend key `stacks/by-id/${terramate.stack.id}/terraform.tfstate`,
  `encrypt = true`, backend `assume_role` into the env's deploy role.
- `config.tm.hcl` holds the `envs` map (account_id, role_arn, region); each
  env dir sets `global.env`; `global.this` resolves the env entry.
- Tag-gated `generate_hcl` with `nogen` guard; generated `.opentofu-version`.

## Bootstrap bundle & IAM/OIDC chain

Per-account foundation, one instance per env via the scaffold file:

- State bucket + DynamoDB lock table (own account).
- Deploy role (the `role_arn` in the envs map) with permissions to build the
  stack surface.
- `infra` only (`ci_entry: true`): GitHub OIDC provider + `gha-ci` entry role
  trusting this repo (`repo:ImIOImI/terramate-eks-hubspoke:*`).
- Every env's deploy role trusts the `gha-ci` role and the human admin ARN.
- CI authenticates once via OIDC to `gha-ci`, then reaches any account
  through the same `assume_role` the backend/provider generators already
  emit.
- **Chicken-and-egg:** bootstrap stacks generate with a local backend first
  (tag-gated backend variant); README walks through local `apply` with admin
  creds, then `tofu init -migrate-state` into the just-created bucket, then
  flipping the tag. Bootstrap stacks are tagged so CI skips them.

## eks-cluster bundle

Inputs: `role` (hub|spoke), `hub_env` (spokes), `node_instance_types`,
`node_scaling`, plus name/env injected via objects.

- **network:** terraform-aws-modules/vpc — VPC, public/private subnets,
  single NAT, SGs.
- **cluster:** terraform-aws-modules/eks — control plane + EKS access entries
  only; core add-ons deferred (`create_cluster_addons = false`) so greenfield
  applies don't deadlock on a nodeless cluster.
- **nodes:** kube-proxy + vpc-cni add-ons first (node group `depends_on`
  them, preserving launch-time CNI config), then managed node group(s) from
  the pool input, then the DaemonSet-safe pod-identity agent add-on.
- **provisioning (both roles):** coredns + ebs-csi add-ons (the
  Deployment-backed pair that needs schedulable nodes) — mirrors a
  deferred-addons split learned from an upstream production deployment.
- **provisioning (hub):** Helm-installed ArgoCD (argo-cd chart) + controller
  IAM role bound via Pod Identity.
- **provisioning (spoke):** registration only —
  1. spoke-access IAM role in the spoke account, trusting the hub controller
     role;
  2. EKS access entry on the spoke cluster for that role (created in
     `cluster/`);
  3. cluster registration Secret written into the hub's `argocd` namespace
     (`argocd.argoproj.io/secret-type: cluster`, `awsAuthConfig` with
     clusterName + roleArn, labels for future ApplicationSet selectors).
  Nothing is deployed to the spoke — the demo endpoint is the spoke showing
  healthy in the hub's Argo UI.
- Kubernetes/Helm providers use EKS exec auth + `assume_role`, which is how
  the spoke's provisioning stack (dev/prd creds) writes to the hub cluster
  (infra role).

## Explicit version pinning (generalized pattern)

> **Note:** Versions below are illustrative from the design phase — `scaffold/cluster.tm.yml` carries the live pins.

Every dependency is pinned in exactly one hand-written place; nothing floats.

| Dependency | Pinned where | Mechanism |
|---|---|---|
| OpenTofu | `config.tm.hcl` → `global.tofu_version` | `required_version` + generated `.opentofu-version` |
| Providers (aws, kubernetes, helm) | `config.tm.hcl` → `global.terraform.providers` map | generated `required_providers` (tpe pattern) |
| terraform-aws-modules (vpc, eks) | scaffold `terraform_modules` input | components emit `source`/`version` from the input |
| EKS managed add-ons (all five) | scaffold `addon_versions` map input | explicit versions on every `aws_eks_addon`; `most_recent = true` is banned |
| ArgoCD Helm chart | scaffold `argocd_chart_version` input | pinned `version` on the `helm_release` |
| Terramate + tofu in CI | workflow env vars at top of each workflow | single place to bump |

Because pins are bundle inputs, a per-environment override in the scaffold
file (e.g. bump `addon_versions.coredns` under `dev:` only) is the
test-in-dev-then-promote story — dependency upgrades ride the same
`promote_from` rail as everything else.

## CI (GitHub Actions, ubuntu-latest)

Installs only: OpenTofu (setup action/tenv), GA terramate `.deb` from GitHub
releases, AWS creds via `aws-actions/configure-aws-credentials` OIDC →
`gha-ci` role.

- **preview.yml** (PR): `terramate generate --check` (no drift between
  scaffold and committed stacks), `tofu fmt -check`, `tofu validate`,
  `tflint`, `trivy config`, then `terramate run --changed -- tofu plan`.
- **deploy.yml** (merge to main): graph-ordered
  `terramate run --changed -- tofu apply`, honoring environment promotion
  (prd after dev).
- Bootstrap stacks excluded by tag until their state is migrated.

## Out of scope (explicit)

Org-specific integrations (VPN, secrets manager, observability vendor),
Karpenter, legacy pinning, aws-system ApplicationSet (registration only),
multi-region, ALB/ingress controllers, external-secrets, LocalStack support.

## Verification plan

- `terramate generate` idempotent + `--check` clean in CI.
- `tofu validate`, `tflint`, `trivy config` clean per stack.
- End-to-end proof: apply order infra/bootstrap → dev/prd bootstrap → hub
  network→cluster→nodes→provisioning → spokes; final state = both spokes
  visible and healthy in hub ArgoCD UI. Teardown order documented (reverse).
- Early spike (before full build): GA 0.17.1 `environments:` BundleInstance
  fan-out proven on a toy bundle.

## Cost note (for README)

3 EKS control planes + 3 NAT gateways + ~7 t3.large nodes ≈ real money
(~$500+/mo if left running). README leads with this and the teardown command.
