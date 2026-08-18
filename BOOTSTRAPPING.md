# Bootstrapping

The order in which you run things matters, and **Terramate will not enforce it for you.**
This document is the authoritative first-run sequence. The [README walkthrough](README.md#deploy-walkthrough)
covers the same ground at a higher level; read this one if you want to know *why*
each step has to come where it does.

---

## TL;DR

```bash
# 0. edit config.tm.hcl (account IDs) and _scaffold-bootstrap.tm.yml (admin ARNs)
make generate                      # stacks/ is committed, so this is usually a no-op

# 1. bootstrap — LOCAL state, admin creds, one account at a time, infra FIRST
#    (`terramate list --run-order --tags bootstrap` prints this order for you)
cd stacks/aws/infra/bootstrap && tofu init && tofu apply && cd -
cd stacks/aws/dev/bootstrap   && tofu init && tofu apply && cd -
cd stacks/aws/prd/bootstrap   && tofu init && tofu apply && cd -

# 2. migrate bootstrap state to the S3 buckets it just created
#    flip state_backend: local -> s3 in _scaffold-bootstrap.tm.yml
make generate
for e in infra dev prd; do (cd stacks/aws/$e/bootstrap && tofu init -migrate-state); done

# 3. only now can the cluster stacks initialize
terramate run --tags env-infra:eks --enable-sharing -- tofu init
terramate run --tags env-infra:eks --enable-sharing -- tofu apply
# ...then env-dev:eks, then env-prd:eks
```

---

## The two scaffolds

Both `BundleInstance` files live at the repo root, prefixed `_scaffold-`:

| File | Bundle | Generates |
|---|---|---|
| `_scaffold-bootstrap.tm.yml` | `bundles/account-bootstrap` | `stacks/aws/{infra,dev,prd}/bootstrap` |
| `_scaffold-cluster.tm.yml` | `bundles/eks-cluster` | `stacks/aws/{infra,dev,prd}/eks/{network,cluster,nodes,provisioning}` |

`terramate generate` reads both regardless of order — **code generation has no
ordering dependency at all.** You can generate everything in one pass on a clean
checkout. The ordering constraint is entirely at `tofu init`/`apply` time.

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
(`state_backend: local` in `_scaffold-bootstrap.tm.yml`), so they need no
pre-existing state infrastructure. That is the only reason the sequence can start
at all. Once they have created the buckets you flip the input to `s3` and migrate
(step 2 above).

### 3. The graph encodes the ordering, but cannot run it for you

Each environment's `network` stack declares `after = /stacks/aws/<env>/bootstrap`,
which anchors that whole environment's chain behind its bootstrap stack —
`cluster`, `nodes`, and `provisioning` inherit the edge transitively. The non-CI
bootstrap stacks in turn declare `after = /stacks/aws/<ci_env>/bootstrap`:

```console
$ terramate list --run-order
bundles/account-bootstrap
bundles/eks-cluster
stacks/aws/infra/bootstrap      # CI account first: it owns the gha-ci role
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

**What the graph still cannot do is apply it in one command**, for two reasons:

- **Credentials change per account.** Each bootstrap stack runs on ambient admin
  credentials for *its own* account, so the three applies cannot share one
  `terramate run` invocation unless you wire up per-stack AWS profiles.
- **Bootstrap is deliberately excluded from CI.** It is not tagged `eks`, so the
  workflows never touch it:

  ```console
  $ terramate list --tags eks | wc -l
  12                            # the 12 cluster stacks; no bootstrap stacks
  ```

  An `after` edge pointing at a stack that the tag filter excluded is honored for
  *ordering* but never pulls the target into the run set — verified with
  `terramate run --tags eks --dry-run`, which lists no bootstrap stack. So CI
  still plans only cluster stacks, and `terramate run --tags eks` on a greenfield
  account will still fail at `tofu init` against a bucket that does not exist.
  The graph tells you the order; it does not tell CI to bootstrap.

---

## Why `infra` bootstrap comes before `dev` and `prd`

Each account's `tmhs-deploy` role trusts the CI entry role **in the infra
account**, which only the infra bootstrap stack creates:

```hcl
# stacks/aws/dev/bootstrap/component_bootstrap__tmgen-bootstrap.tf
resource "aws_iam_role" "deploy" {
  assume_role_policy = jsonencode({
    Statement = [{
      Principal = { AWS = ["arn:aws:iam::111111111111:role/tmhs-gha-ci"] }
      Action    = "sts:AssumeRole"
    }]
  })
  name = "tmhs-deploy"
}
```

IAM rejects a trust policy naming a principal that does not exist
(`MalformedPolicyDocument`), so applying the `dev` or `prd` bootstrap before the
`infra` one will fail. Apply infra first, then the spokes in any order.

This is encoded: the account-bootstrap bundle takes a `ci_env` input (default
`infra`) naming the account that owns the OIDC provider and `gha-ci` role, and
every stack whose `ci_entry` is false declares `after = /stacks/aws/<ci_env>/bootstrap`.
The CI account's own bootstrap gets an empty `after`, so there is no cycle. The
same input feeds the trust-policy ARN in `components/bootstrap`, so the edge and
the policy can never disagree.

```console
$ terramate list --tags ci-entry
stacks/aws/infra/bootstrap
```

---

## Add your own admin ARN or you will lock yourself out

With `admin_principal_arns: []` (the shipped default) the only principal that can
assume `tmhs-deploy` is the GitHub Actions CI role. Every cluster stack's backend
does `assume_role { role_arn = ...tmhs-deploy }`, so a **local** `tofu init` on a
cluster stack fails with an `AccessDenied` on `sts:AssumeRole` unless your own
identity is in the trust policy.

Before step 1, add your ARNs to `_scaffold-bootstrap.tm.yml`:

```yaml
spec:
  inputs:
    admin_principal_arns:
      - "arn:aws:iam::111111111111:user/your-admin-user"
      - "arn:aws:iam::222222222222:user/your-admin-user"
      - "arn:aws:iam::333333333333:user/your-admin-user"
```

If you only ever apply through CI you can leave this empty.

---

## Mint-then-wire: only if you regenerate `stacks/` from scratch

`stacks/` is committed, and `_scaffold-cluster.tm.yml` already carries stack UUIDs
that match it. A plain clone needs none of this.

You need it when you **delete `stacks/`** or **rename a stack path**, because
Terramate mints a fresh UUID per stack and two generated things key off that UUID:

- the S3 state `key` (`stacks/by-id/<uuid>/terraform.tfstate`)
- every cross-stack sharing input's `from_stack_id`

The UUIDs do not exist until the first `generate`, so the scaffold cannot name them
up front. The loop:

```bash
# 1. drop the stale ids so the bundle's placeholder-UUID defaults apply
#    (delete every *_stack_id: line under environments.<env>.inputs)
make generate        # mints 12 stacks, each writing a fresh UUID into stack.tm.hcl

# 2. read the minted UUIDs back into the scaffold
make wire            # scripts/wire-stack-ids.sh — idempotent

# 3. converge
make generate        # sharing blocks now carry real from_stack_ids
make generate        # no-op; proves convergence
```

`make wire` discovers the environments from `stacks/aws/*/eks/network` and picks
the hub as the env whose `provisioning` stack got the `argocd-hub` component, then
writes per-env:

| Key | Value |
|---|---|
| `network_stack_id` | that env's `eks/network` UUID |
| `cluster_stack_id` | that env's `eks/cluster` UUID |
| `hub_cluster_stack_id` | the hub's `eks/cluster` UUID (spoke envs only) |

> **Re-minting orphans live state.** The state key is derived from the UUID, so a
> re-mint points every stack at a new, empty S3 key. Only do this on a greenfield
> repo, or migrate state deliberately afterward.

---

## Verifying the sequence without touching AWS

Everything above except the applies can be checked offline:

```bash
make generate                              # idempotent; "Nothing to do" on a clean clone
make check                                 # generate + fail if it dirtied the tree
terramate list --run-order                 # whole-repo order, bootstrap first
terramate list --run-order --tags bootstrap  # the three bootstrap applies, in order
terramate list --run-order --tags env-dev  # one env end to end, bootstrap included
terramate list --tags eks | wc -l          # 12 — proves CI still excludes bootstrap
terramate run --tags eks --dry-run -- true # no bootstrap stack appears
grep -A4 'backend "s3"' stacks/aws/dev/eks/network/component_required__tmgen-terraform.tf
```

## Tag reference

| Tag | Selects |
|---|---|
| `bootstrap` | the three account-bootstrap stacks |
| `ci-entry` | just the account that owns the OIDC provider + `gha-ci` role |
| `eks` | the 12 cluster stacks — **the CI filter; excludes bootstrap** |
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
