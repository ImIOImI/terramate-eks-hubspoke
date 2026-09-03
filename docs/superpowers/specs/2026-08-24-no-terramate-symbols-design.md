# No-Terramate, symbols-DRY: design + verified PoC

What this repo looks like with **Terramate removed entirely**, kept DRY using
OpenTofu **symbol libraries** ([opentofu/opentofu#4052][rfc], experiment merged
to `main` 2026-08-24 in [#4474][impl]) plus native OpenTofu (modules +
`terraform_remote_state`). A working `dev`-chain PoC ships alongside this doc.

## What replaces each Terramate mechanism

| Terramate today | No-Terramate replacement |
| --- | --- |
| `globals` (envs, versions, tags) | **`symbols` values/functions** — `lib/config` |
| `lets` + `tm_*` (ARNs, CIDR math) | **`symbols` functions** — `lib/naming`, `lib/net` |
| inline IAM `jsonencode` | **`symbols` functions** — `lib/iam` (the earlier spike) |
| `generate_hcl` component templates | **native child modules** — `modules/*` |
| generated per-stack `.tf` | **thin root modules** — `envs/<env>/<tier>/main.tofu` |
| outputs-sharing (`input`/`output`) | **`terraform_remote_state`** data sources |
| bundle fan-out across envs | *(no pure-HCL equivalent — see Limits)* |

## Layout

```
lib/                       # shared DATA + pure LOGIC (symbol libraries)
  config/  naming/  net/  iam/
modules/                   # resource bodies (were components/*)
  bootstrap/ network/ eks-cluster/ eks-nodes/ provisioning/
envs/                      # thin roots, one per env×tier (own state)
  dev/{bootstrap,network,cluster,nodes,provisioning}/main.tofu
```

Where symbols are used:
- **Roots** import `config` + `naming` — resolve env → values, wire providers,
  build `terraform_remote_state` config, compute ARNs.
- **Modules** import `net` + `iam` as internal helpers (subnet math; policy docs).
- `naming` imports `config` (cross-library reference — verified working).

## Config: defaults + per-env overrides via a pure deepmerge

`config` holds the *entire* configuration as data: a `defaults()` base plus an
`overrides()` map of only what each environment changes. `env(id)` deep-merges
the two, and every other accessor (`account_id`, `region`, `node_scaling`,
`addon_versions`, `hub_env`, …) derives from `env(id)` — so `prd` can widen its
node group with a three-line override and nothing else changes.

Symbols are pure and **cannot call the Terraform deepmerge module**, so the
merge is a pure recursive symbol. This is not just a workaround — it's required:
the merged config must live *inside* symbols so `naming`, state-addressing, and
the roots can all derive from it. A module's output couldn't be reached from
another symbol.

```hcl
function "env" {
  parameter "id" { type = string }
  return = symbols::deepmerge(symbols::defaults(), symbols::overrides()[param.id])
}
function "deepmerge" {           # over wins; two maps merge; else replace
  parameter "base" { type = any }
  parameter "over" { type = any }
  return = { for k in distinct(concat(keys(param.base), keys(param.over))) : k => (
    contains(keys(param.base), k) && contains(keys(param.over), k) && can(keys(param.base[k])) && can(keys(param.over[k]))
    ? symbols::deepmerge(param.base[k], param.over[k])
    : (contains(keys(param.over), k) ? param.over[k] : param.base[k])
  ) }
}
```

Verified: `env("prd")` yields `node_scaling = {min=3,max=6}` and
`node_instance_types = ["m5.xlarge"]` (overrides) while inheriting every default;
`env("dev")` keeps the defaults. **Recursion caveat:** direct symbol self-
recursion is blocked by the compiler (`Recursive call detected`), but recursion
*through a `for`-comprehension* — as in `deepmerge` — is permitted and verified
to 3+ levels. A fixed 2-level merge is the fallback if that ever tightens.

## How remote-state wiring looks

Symbols are **pure** — a symbol can't read state. It builds the *address*; the
(impure) read stays native in the root:

```hcl
# lib/config
function "remote_state" {
  parameter "env"  { type = string }
  parameter "tier" { type = string }
  return = {
    bucket = symbols::state_bucket(param.env)
    key    = symbols::state_key(param.env, param.tier)
    region = symbols::region(param.env)
  }
}
```
```hcl
# envs/dev/nodes/main.tofu
data "terraform_remote_state" "cluster" {
  backend = "s3"
  config  = symbols::cfg::remote_state("dev", "cluster")
}
module "nodes" {
  cluster_service_cidr = data.terraform_remote_state.cluster.outputs.cluster_service_cidr
}
```

Cross-**env** wiring is the same call with a different env — `envs/dev/provisioning`
reads the hub with `symbols::cfg::remote_state("infra", "cluster")` to register
the spoke into the hub ArgoCD.

## A root module in full (the payoff)

`envs/dev/network/main.tofu` is ~40 lines and the only env-specific token is the
literal `"dev"` and the backend block:

```hcl
language { experiments = [symbol_libraries] }
symbols "cfg"  { source = "../../../lib/config" }
symbols "name" { source = "../../../lib/naming" }

terraform {                       # static context — literal only (see Limits)
  required_version = ">= 1.11.0"
  required_providers { aws = { source = "hashicorp/aws", version = "~> 6.0" } }
  backend "s3" { bucket = "tmhs-state-dev-222222222222"; key = "...network..."; region = "us-east-1" }
}

provider "aws" {
  region = symbols::cfg::region("dev")
  assume_role { role_arn = symbols::name::deploy_role_arn("dev") }
  default_tags { tags = symbols::cfg::tags() }
}

module "network" {
  source       = "../../../modules/network"
  cluster_name = symbols::cfg::cluster_name("dev")
  region       = symbols::cfg::region("dev")
  vpc_cidr     = symbols::cfg::vpc_cidr("dev")
  tags         = symbols::cfg::tags()
}
```

## Verified limits (empirically, with a symbols-capable `tofu`)

1. **Symbols are pure** — a `.sym.hcl` function referencing
   `data.terraform_remote_state.*` sees `data` as **null**. No state reads,
   resource refs, or `var`/`local` inside symbols.
2. **The `terraform{}` block is a static context** — `required_version`,
   `required_providers`, and `backend` reject *all* function/symbol calls
   (`Functions may not be called here`). This literal boilerplate is irreducible
   per root; Terramate codegen used to emit it.
3. **Fan-out is not expressible in pure HCL** — there is still one root dir per
   state boundary (env×tier), each naming its own `env`. Multi-account state
   isolation rules out the `for_each`/workspaces collapse. Eliminating those
   ~15-line near-identical roots is exactly what a codegen/orchestration layer
   (Terramate bundles) provides. **This is the honest answer to "what does
   Terramate buy you": the `terraform{}` boilerplate and the fan-out.**

Everything else — all env data, ARNs, CIDR math, policy documents, provider
config, module wiring, and remote-state addressing — is fully DRY via symbols.

## Verification (PoC, built from `opentofu@5097d2de`)

- `tofu init -backend=false && tofu validate` passes on all five `dev` roots,
  including cross-env remote_state and the `kubernetes.hub` provider.
- A values `apply` confirms every symbol resolves correctly, e.g.
  `cluster_name → tmhs-eks-dev`, `deploy_role_arn → arn:aws:iam::222…:role/tmhs-deploy`,
  `private_subnets → ["10.1.0.0/20","10.1.16.0/20"]`, `remote_state → {bucket,key,region}`.
- Multi-file libraries and cross-library references both verified.
- `tofu fmt -check`, `tflint`, `trivy config` clean.

## Scope

PoC covers the `dev` spoke chain only. `infra` (hub) and `prd` follow the
identical pattern — each is another `envs/<env>/<tier>/` root of the same shape.
The Terramate files (`components/`, `bundles/`, `stacks/`, `*.tm.hcl`) are left
in place for side-by-side comparison; a real cutover would delete them.

[rfc]: https://github.com/opentofu/opentofu/pull/4052
[impl]: https://github.com/opentofu/opentofu/pull/4474
