# Bootstrapping

The order in which you run things matters, and **Terramate will not enforce it for you.**
This document is the authoritative first-run sequence. The [README walkthrough](README.md#deploy-walkthrough)
covers the same ground at a higher level; read this one if you want to know *why*
each step has to come where it does.

---

> For a local, no-AWS run of this same sequence, see [MINISTACK.md](MINISTACK.md) —
> the `ci-hub` environment does all of it against MiniStack in about three minutes.

## TL;DR

```bash
# 0. edit config.tm.hcl (account IDs); _scaffold-cluster.tm.yml only if you use SSO
make stacks                        # seed derived stack ids (no-op on a plain clone)
make generate                      # stacks/ is committed, so this is usually a no-op

# 1. stand each account up end to end, one command, from your admin creds
#    (infra FIRST: the spokes' deploy roles trust the gha-ci role it creates)
make apply ENV=infra               # bootstrap -> network -> cluster -> nodes -> provisioning
make apply ENV=dev
make apply ENV=prd
```

`make apply` runs the tiers in order (outputs-sharing forbids a whole-chain init).
On the create path, `bootstrap` creates `tmhs-deploy`, trusts your caller via
`data.aws_caller_identity`, and a propagation gate waits until STS honors the
assume before the eks tiers assume it — so it all works in one invocation.
**Requires the AWS CLI** on your machine (the gate polls `sts assume-role`).

The manual, tier-by-tier equivalent — and the one-time migration of *bootstrap's
own* state from local to S3 — is spelled out below.

```bash
# manual bootstrap (what `make apply` automates for the bootstrap tier):
terramate run --tags env-infra:bootstrap -- tofu init
terramate run --tags env-infra:bootstrap -- tofu apply     # LOCAL state, admin creds
# migrate bootstrap state to the S3 bucket it just created (optional, one-time):
#   flip state_backend: local -> s3 in _scaffold-cluster.tm.yml, make generate,
#   then: (cd stacks/aws/infra/bootstrap && tofu init -migrate-state)
```

---

## The scaffold

One `BundleInstance` file at the repo root drives the whole per-account tree
(bootstrap was folded in from the former `account-bootstrap` bundle):

| File | Bundle | Generates |
|---|---|---|
| `_scaffold-cluster.tm.yml` | `bundles/eks-cluster` | `stacks/aws/<env>/bootstrap` + `stacks/aws/<env>/eks/{network,cluster,nodes,provisioning}` |

`terramate generate` has **no ordering dependency at all** — you can generate
everything in one pass on a clean checkout. The ordering constraint is entirely at
`tofu init`/`apply` time (which `make apply` sequences for you).

---

## Why bootstrap has to run first

### 1. Cluster stacks store state in a bucket bootstrap creates

Every generated cluster stack carries an S3 backend that does not exist yet on a
fresh account:

```hcl
# stacks/aws/dev/eks/network/component_required__tmgen-terraform.tf
backend "s3" {
  bucket         = "tmhs-state-dev-222222222222"   # created by the dev bootstrap stack
  dynamodb_table = "tmhs-locks-dev"                # created by the dev bootstrap stack
  key            = "stacks/by-id/<stack-uuid>/terraform.tfstate"
  assume_role {
    role_arn = "arn:aws:iam::222222222222:role/tmhs-deploy"  # created by the dev bootstrap stack
  }
}
```

`tofu init` on that stack fails before it does anything else if the bucket, the
lock table, or the role is missing. There is no `-backend=false` escape hatch for
a real apply.

### 2. Bootstrap breaks the chicken-and-egg with local state

The bootstrap stacks are generated with `backend "local"` on the first pass
(`state_backend: local` in `_scaffold-cluster.tm.yml`), so they need no
pre-existing state infrastructure. That is the only reason the sequence can start
at all. Once they have created the buckets you flip the input to `s3` and migrate
(step 2 above).

### 3. The graph encodes the ordering, but cannot run it for you

Each environment's `network` stack declares `after = /stacks/aws/<env>/bootstrap`,
which anchors that whole environment's chain behind its bootstrap stack —
`cluster`, `nodes`, and `provisioning` inherit the edge transitively. The non-CI
bootstrap stacks in turn declare `after = /stacks/aws/<oidc_entry_env>/bootstrap`:

```console
$ terramate list --run-order
bundles/eks-cluster
stacks/aws/infra/bootstrap      # OIDC-entry account first: it owns the gha-ci role
stacks/aws/dev/bootstrap        # spokes' deploy roles trust that role
stacks/aws/infra/eks/network    # each env's eks chain sits behind its own bootstrap
stacks/aws/prd/bootstrap
stacks/aws/dev/eks/network
stacks/aws/infra/eks/cluster
...
```

That makes `--run-order` and any whole-repo run correct by construction, and it
gives you a correctly ordered per-environment sequence:

```console
$ terramate list --run-order --tags env-dev
stacks/aws/dev/bootstrap
stacks/aws/dev/eks/network
stacks/aws/dev/eks/cluster
stacks/aws/dev/eks/nodes
stacks/aws/dev/eks/provisioning
```

`make apply ENV=<id>` applies **one account** end to end in a single command
(bootstrap on your ambient creds, then the eks tiers assuming the deploy role the
bootstrap gate just made assumable). What it still cannot do is apply **all**
accounts at once, for two reasons:

- **Credentials change per account.** Each account's bootstrap runs on ambient
  admin credentials for *its own* account, so you run `make apply` once per account
  (with that account's creds) — infra first.
- **Bootstrap is deliberately excluded from CI.** It is not tagged `eks`, so the
  workflows never touch it:

  ```console
  $ terramate list --tags eks --no-tags local | wc -l
  12                            # the real-AWS cluster stacks; no bootstrap stacks
  ```

  An `after` edge pointing at a stack that the tag filter excluded is honored for
  *ordering* but never pulls the target into the run set — verified with
  `terramate run --tags eks --dry-run`, which lists no bootstrap stack. So CI
  still plans only cluster stacks, and `terramate run --tags eks` on a greenfield
  account will still fail at `tofu init` against a bucket that does not exist.
  The graph tells you the order; it does not tell CI to bootstrap.

---

## Why `infra` bootstrap comes before `dev` and `prd`

Each account's `tmhs-deploy` role trusts the `gha-ci` entry role **in the infra
account**, which only the infra bootstrap stack creates. On real AWS the trust
list is `gha-ci` + the auto-derived caller + any `admin_principal_arns`:

```hcl
# stacks/aws/dev/bootstrap/component_bootstrap__tmgen-deploy-role.tf
resource "aws_iam_role" "deploy" {
  assume_role_policy = jsonencode({
    Statement = [{
      Principal = { AWS = local.deploy_trust }  # gha-ci + caller (+ admin_principal_arns)
      Action    = "sts:AssumeRole"
    }]
  })
  name = "tmhs-deploy"
}
```

IAM rejects a trust policy naming a principal that does not exist
(`MalformedPolicyDocument`), so applying the `dev` or `prd` bootstrap before the
`infra` one will fail (its `gha-ci` ARN wouldn't exist yet). Apply infra first,
then the spokes in any order.

This is encoded: the eks-cluster bundle takes an `oidc_entry_env` input (default
`infra`) naming the account that owns the OIDC provider and `gha-ci` role, and
every stack whose `oidc_entry` is false declares
`after = /stacks/aws/<oidc_entry_env>/bootstrap`. The entry account's own
bootstrap gets an empty `after`, so there is no cycle. The same input feeds the
trust-policy ARN in `components/bootstrap`, so the edge and the policy can never
disagree.

```console
$ terramate list --tags oidc-entry
stacks/aws/infra/bootstrap
stacks/aws/ci-hub/bootstrap
```

---

## Trusting your own identity

On the **create path**, bootstrap auto-trusts whoever runs it: it reads
`data.aws_caller_identity`, normalizes your assumed-role session ARN to its IAM
role ARN, and adds it to `tmhs-deploy`'s trust. So `make apply ENV=<id>` (and any
local `tofu` you run against a cluster stack, whose backend does
`assume_role { role_arn = ...tmhs-deploy }`) can assume the role with no extra
config. A propagation gate in bootstrap waits until the assume actually works
before the eks tiers run.

Two cases still need `admin_principal_arns` (set in `_scaffold-cluster.tm.yml`):

- **AWS SSO** — reserved-SSO role ARNs can't be reconstructed from the STS session
  ARN, so auto-derivation skips them; name your role explicitly:
  ```yaml
  spec:
    inputs:
      admin_principal_arns:
        - "arn:aws:iam::111111111111:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_Admin_xxxx"
  ```
- **Extra principals** — a separate automation role or a teammate who should also
  assume the deploy role.

If you only ever apply through GitHub Actions, leave it empty — the `gha-ci` role
is always trusted.

### Adopting an existing deploy role

Set `deploy_role_arn` on an env (in `_scaffold-cluster.tm.yml`) to skip bootstrap
entirely and have the eks tiers assume a role you already manage. **Precondition:
that role must already exist and be assumable by your current identity** — we do
not create it, verify it, or grant it trust. Supplying it also implies the
account's S3 state backend already exists.

---

## Stack ids are derived, not minted

Terramate assigns each stack a UUID **only when `stack.tm.hcl` does not already
exist**. This repo seeds that file first, so the ids are ours:

```console
$ make stacks
stack ids: 15 created, 0 corrected, 0 already correct

$ cat stacks/aws/dev/eks/network/stack.tm.hcl
stack {
  id = "dev-eks-network"
}
```

The id is a pure function of the stack path — strip `/stacks/aws/`, turn `/` into
`-`:

| Stack path | Id |
|---|---|
| `/stacks/aws/dev/eks/network` | `dev-eks-network` |
| `/stacks/aws/infra/bootstrap` | `infra-bootstrap` |

`make/stack-ids.sh` computes this by reading the `environments:` keys out of each
root `_scaffold-*.tm.yml` and the `metadata.path` templates out of that scaffold's
bundle, so nothing is hardcoded — adding an environment adds its stacks
automatically. `make/create-stacks.sh` then writes each `stack.tm.hcl`.

Because the formula is reproducible, the bundle computes the same ids inline and
**cross-stack sharing needs no wiring inputs at all**:

```hcl
# bundles/eks-cluster/bundle.tm.hcl
network_stack_id     = "${bundle.environment.id}-eks-network"
hub_cluster_stack_id = "${bundle.input.hub_env.value}-eks-cluster"
```

That replaced the old mint-then-wire loop (generate to mint UUIDs, read them back,
paste them into the scaffold, regenerate). The scaffold now carries only intent:

```yaml
environments:
  dev:
    inputs:
      role: spoke
      hub_env: infra
```

State keys are readable as a side effect —
`stacks/by-id/dev-eks-network/terraform.tfstate` rather than
`stacks/by-id/25cbafe4-.../terraform.tfstate`.

### Adding an environment

1. Add an `environment {}` block in `terramate.tm.hcl` and an `envs` entry in
   `config.tm.hcl`.
2. Add the env key to `_scaffold-cluster.tm.yml`.
3. `make stacks && make generate`.

No id wiring, no UUID round trip.

### The one coupling to respect

The formula lives in two places: `id_for()` in `make/stack-ids.sh`, and the inline
expressions in `bundles/eks-cluster/bundle.tm.hcl`. If they drift, sharing breaks.
`make check-ids` (part of `make check`, which CI runs) fails the build if any
`stack.tm.hcl` id no longer matches its derived value:

```console
$ make check-ids
stack ids up to date (15 stacks)
```

> **Changing an id changes that stack's state key.** `make stacks` prints a
> `(state key changes)` warning when it corrects one. Harmless before the first
> apply; after one, migrate the state deliberately.

> The two `bundles/*/stack.tm.hcl` definition stacks keep their hand-written
> UUIDs. They carry no `.tf` files and are not part of the fan-out.

---

## Verifying the sequence without touching AWS

Everything above except the applies can be checked offline:

```bash
make generate                              # idempotent; "Nothing to do" on a clean clone
make check-ids                             # fail if any stack id drifted from its derived value
make check                                 # check-ids + generate + fail if it dirtied the tree
terramate list --run-order                 # whole-repo order, bootstrap first
terramate list --run-order --tags bootstrap --no-tags local  # the three real bootstrap applies, in order
terramate list --run-order --tags env-dev  # one env end to end, bootstrap included
terramate list --tags eks --no-tags local | wc -l  # 12 — the real-AWS cluster stacks CI plans (excludes bootstrap + local ci-hub)
terramate run --tags eks --no-tags local --dry-run -- true # no bootstrap or local stack appears
grep -A4 'backend "s3"' stacks/aws/dev/eks/network/component_required__tmgen-terraform.tf
```

## Tag reference

| Tag | Selects |
|---|---|
| `bootstrap` | the bootstrap stacks (one per env; 3 real + local `ci-hub`) |
| `oidc-entry` | the accounts that own a GitHub OIDC provider + `gha-ci` role (`infra`, `ci-hub`) |
| `eks` | the cluster stacks — **CI filters `eks` + `--no-tags local` → the 12 real-AWS stacks; excludes bootstrap** |
| `local` | MiniStack-backed stacks (the `ci-hub` env); excluded from CI |
| `env-<id>` | everything in one environment, bootstrap included |
| `env-<id>:eks` | one environment's four cluster stacks (CI's per-env filter) |
| `role-hub` / `role-spoke` | cluster stacks by hub/spoke role, across environments |
| `network` / `cluster` / `nodes` / `provisioning` | one tier across all environments |

Combine with `:` for AND — `--tags env-prd:eks`. Add `--run-order` to any of them
to get the correct apply sequence.

---

## Teardown order is the exact reverse

Spokes before hub, `provisioning → nodes → cluster → network` within each env, and
bootstrap last. See [Teardown](README.md#teardown).
