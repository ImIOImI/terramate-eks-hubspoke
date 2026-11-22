# Toolchain versions and tested ranges

| Tool | Pinned | Where | Tested range |
|---|---|---|---|
| Terramate (GA) | `0.17.4` in CI, `required_version = ">= 0.17.0, < 0.18.0"` | `.github/actions/setup/action.yml`, `terramate.tm.hcl` | 0.17.0 – 0.17.4 |
| OpenTofu | `1.13.9` (exact) | `config.tm.hcl` → `required_version` + `.opentofu-version` in every stack | 1.6.0 – 1.13.9 |
| hashicorp/aws | `~> 6.52`, locked at `6.73.0` | `config.tm.hcl`, `.terraform.lock.hcl` | 6.52.0 – 6.73.0 |

Tested 2026-11-21 with `make compat` (see below). The upgrade was from
Terramate 0.17.1 / OpenTofu 1.11.5 / AWS 6.54.0 (6.60.0 in the `ci-hub` locks).
The other providers (kubernetes, helm, tls, cloudinit, null, time) were left at
their locked versions.

## Results

`validate` = generation byte-identical + `tofu validate` on every non-local stack.
`apply` = the full `ci-hub` chain on MiniStack (bootstrap → network → cluster →
nodes → provisioning, ArgoCD running in k3s).

| Terramate | OpenTofu | AWS | Mode | Result |
|---|---|---|---|---|
| 0.17.4 | 1.13.9 | 6.73.0 | apply | PASS (all seven ArgoCD pods `Running`) |
| 0.17.0 | 1.6.0 | 6.52.0 | apply | PASS (every floor at once) |
| 0.17.0, 0.17.1, 0.17.2, 0.17.3, 0.17.4 | 1.13.9 | 6.73.0 | validate | PASS |
| 0.16.0 | 1.13.9 | 6.73.0 | validate | FAIL: `unrecognized "define" child block` in `bundles/eks-cluster/bundle.tm.hcl` |
| 0.17.4 | 1.6.3, 1.8.11, 1.9.4, 1.11.5, 1.13.9 | 6.73.0 | validate | PASS |
| 0.17.4 | 1.13.9 | 6.52.0 | validate | PASS |
| 0.17.4 | 1.13.9 | 6.51.0 | validate | FAIL: `terraform-aws-modules/eks` 21.24.0 requires `>= 6.52.0` |

What sets each floor:

- **Terramate 0.17.0**: the bundle `define` syntax. The upper bound is the next
  untested minor; Terramate is pre-1.0, so a minor may break things.
- **AWS 6.52.0**: the EKS module's own constraint, not this repo's code. Bumping
  the module may raise it.
- **OpenTofu 1.6.0**: the first OpenTofu release; nothing in the repo needs a newer one.
  The repo still pins one exact version, so this range only says what a bump
  can safely move between.

MiniStack does not exercise everything (see [MINISTACK.md](../MINISTACK.md)):
exec-auth, IRSA and the SSM AMI lookup only run against real AWS.

## Re-running

```bash
make compat TM=0.17.4 TOFU=1.13.9 AWS=6.73.0              # validate, ~5 min
make compat TM=0.17.0 TOFU=1.6.0 AWS=6.52.0 MODE=apply    # MiniStack, ~4 min, needs Docker
```

Each run uses a throwaway worktree of HEAD (commit first). Binaries and providers
are cached in `~/.cache/terramate-eks-hubspoke/compat`.

To bump a version: run the new one through `make compat` (both modes), update
the pin(s) above, `make generate`, then refresh only that provider's lock entries.
