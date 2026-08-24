# Spike: DRY IAM policies via OpenTofu Symbol Libraries

Refactors the repeated inline IAM policy documents into a shared OpenTofu
**symbol library** (`symbols::iam::*`), enabled by the `symbol_libraries`
language experiment ([opentofu/opentofu#4052][rfc], implementation merged to
`main` 2026-08-24 in [#4474][impl], commit `5097d2de`).

## What symbols are

A `symbols "ns" { source = "./lib" }` block binds a directory of `*.sym.hcl`
files that declare pure `function`/`values`/`typedef` blocks, called as
`symbols::ns::name(args)`. It's reusable pure code (functions + values) without
the overhead of a module — the layer Terramate globals/`lets` can't reach,
because Terramate has no user-defined parameterized functions.

## The duplication this removes

Eight `jsonencode({...})` IAM policy documents across four components, with
`Version = "2012-10-17"` repeated seven times and the pod-identity trust block
byte-for-byte duplicated between `eks-core-addons` and `argocd-hub`. Only the
IAM policy JSON is a real symbols target: cluster naming, CIDR math, and the
access-entry shape are computed at `terramate generate` time and baked to
literals, which Terramate already DRYs.

| Component | Was | Now |
| --- | --- | --- |
| `bootstrap` deploy | inline AWS-principal trust | `symbols::iam::aws_principal_trust(...)` |
| `bootstrap` gha-ci | inline GitHub OIDC trust | `symbols::iam::github_oidc_trust(...)` |
| `bootstrap` gha-ci assume | inline permission policy | `symbols::iam::assume_role_policy(...)` |
| `eks-core-addons` ebs_csi | inline pod-identity trust | `symbols::iam::pod_identity_trust()` |
| `argocd-hub` controller | inline pod-identity trust (dup) | `symbols::iam::pod_identity_trust()` |
| `argocd-hub` assume-spokes | inline permission policy | `symbols::iam::assume_role_policy(...)` |
| `argocd-spoke` spoke_access | inline AWS-principal trust | `symbols::iam::aws_principal_trust(...)` |

## Layout

- `lib/iam/iam.sym.hcl` — the library, authored once at the project root.
- `components/symbols-iam/` — emits, per stack, the `language { experiments =
  [symbol_libraries] }` gate + `symbols "iam" { source = ... }` block. The
  `source` is a local path, so the `../` prefix is computed from the stack's
  depth (`terramate.stack.path.relative`). Included in the bootstrap and
  provisioning bundle stacks.
- Components emit the calls via `tm_hcl_expression(...)` so Terramate passes the
  `symbols::iam::*` expression through verbatim instead of evaluating it at
  generate time; generate-time values are embedded as HCL literals with
  `${tm_jsonencode(...)}`, and runtime references (e.g. the OIDC provider ARN)
  are passed through as-is.

## No-op guarantee

Each function returns the same structure through the same `jsonencode`, so the
rendered policy JSON is identical — `tofu plan` shows no change. `aws_principal_trust`
takes `actions` as a passthrough parameter (not a `bool` flag) specifically so
the `Action` field keeps its original type (string for the deploy role, list for
the spoke role).

## Verification (this spike)

Run against a symbols-capable build (`tofu` nightly ≥ `20260825`, or built from
`opentofu@5097d2de`):

- `tofu init && tofu apply` on a standalone fixture — all six functions render
  JSON byte-identical to the previous inline documents.
- `tofu init -backend=false && tofu validate` — passes on every affected stack:
  `infra/bootstrap`, `dev/bootstrap`, `prd/bootstrap`, `infra/eks/provisioning`
  (hub, +helm), `dev/eks/provisioning` and `prd/eks/provisioning` (spokes).
- The pre-merge `20260824` nightly rejects the experiment
  (`no current experiment with the keyword "symbol_libraries"`), confirming the
  gate.

## CI

`.github/actions/setup` installs the OpenTofu nightly from
`nightlies.opentofu.org` (pinned via `tofu_nightly_date`, default `20260825`,
guarded to reject anything older) instead of `opentofu/setup-opentofu`, because
symbols are not in any stable release yet. `tflint`/`tofu fmt` are unaffected —
tflint ignores the unknown top-level blocks and does not scan `.sym.hcl`.

## Caveat

`symbol_libraries` is an **experiment**, not stable. This branch is a spike:
adopt on `main` only once the experiment stabilizes and ships in a release.

[rfc]: https://github.com/opentofu/opentofu/pull/4052
[impl]: https://github.com/opentofu/opentofu/pull/4474
