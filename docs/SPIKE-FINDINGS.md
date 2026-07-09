# SPIKE-FINDINGS — GA Terramate mechanics (Task 0)

**This file is the binding syntax authority for every later task.** Where a
later task's HCL/YAML conflicts with a snippet here, the snippet here wins and
the executor adapts mechanically (same inputs/outputs, corrected syntax).

Every snippet below was run on the box against the pinned binary and is quoted
verbatim (working config, or the exact failure + the chosen fallback). Spike
scratch repo left in place at `/tmp/tm-spike` for post-hoc inspection.

- **Binary:** `terramate 0.17.1` (GA / standard distribution).
- **tofu:** `OpenTofu v1.11.5`.
- **Probe date:** 2026-07-09.

---

## D. Terramate version + install (answered first; it gates everything)

**Landed on: GA Terramate `0.17.1`.** Meets the plan's `>=0.17.1` requirement,
so **no install was needed** — the box already had it, tenv-managed.

```
$ terramate version
0.17.1
```

**How it's provided on this box:** `/usr/bin/terramate` is a real ELF binary
resolved through **tenv** to `/opt/tenv/Terramate/0.17.1/terramate`
(`tenv terramate list` → `* 0.17.1 (used 2026-07-09, set by /opt/tenv/Terramate/version)`).

**Confirmed GA, not Catalyst** (the distinction matters — Catalyst is a
v0.15.6-line pseudo-version behind GA on schema):

- GA tell: `terramate package` has **no** subcommands
  (`terramate package create` → `Error: unexpected command sequence` / `unexpected argument`).
  Catalyst ships `package create`; GA does not.
- GA has `terramate ui`; Catalyst does not. (Not exercised here, but recorded.)
- No `catalyst` string in `terramate version`; the `.deb`/APT `terramate-catalyst`
  package is not installed (`dpkg -l | grep terramate` empty).

**Install command to pin GA >=0.17.1 in CI / a fresh box** (for Task 1 / Task 12
to reference — the box didn't need it, but the plan asks for the command):

```bash
# Option A (what this box uses) — tenv:
tenv terramate install 0.17.1 && tenv terramate use 0.17.1

# Option B — GA tarball from GitHub releases (x86_64):
VER=0.17.1
curl -fsSL -o /tmp/terramate.tar.gz \
  https://github.com/terramate-io/terramate/releases/download/v${VER}/terramate_${VER}_linux_x86_64.tar.gz
tar -xzf /tmp/terramate.tar.gz -C /usr/local/bin terramate
terramate version   # -> 0.17.1

# Option C — GA .deb (Debian/Ubuntu CI runners):
VER=0.17.1
curl -fsSL -o /tmp/terramate.deb \
  https://github.com/terramate-io/terramate/releases/download/v${VER}/terramate_${VER}_linux_amd64.deb
sudo dpkg -i /tmp/terramate.deb
```

> NOTE: GA releases are on GitHub; **Catalyst betas are NOT on GitHub releases**
> (they come via the Terramate APT repo). For this public showcase we want GA,
> which is the GitHub-release path — good, it keeps CI install simple.

---

## A. BundleInstance `environments:` fan-out — **WORKS on GA 0.17.1**

The plan's assumption holds, with **two corrections** the design must adopt.

### A.1 — `environment {}` blocks take **NO label**; id is an `id =` attribute

The plan brief wrote `environment "infra" {}`. That is **rejected**:

```
> terramate.tm.hcl:7,13-20: terramate schema error: environment block must have no labels but got 1
```

Enumerated schema (probed by injecting a bogus attr):

```
> terramate schema error: valid attributes are [description, id, name, promote_from] but found "bogus_attr"
```

**VERBATIM WORKING root config** (`terramate.tm.hcl` at repo root):

```hcl
terramate {
  config {
    experiments = ["outputs-sharing"]
  }
}

environment {
  id          = "infra"
  name        = "Infrastructure"
  description = "infra env"
}

environment {
  id          = "dev"
  name        = "Development"
  description = "dev env"
}

environment {
  id           = "prd"
  name         = "Production"
  description  = "prd env"
  promote_from = "dev"
}
```

`promote_from = "dev"` on `prd` is accepted (no error). It is a promotion-graph
hint; it does **not** by itself change generation output.

### A.2 — The bundle must **opt in** to environments, or the YAML `environments:` key is rejected

With a plain bundle, the `.tm.yml` `environments:` key fails:

```
> scaffold/echo.tm.yml:10,3-0,0: the bundle defiend at '/scaffold/echo.tm.yml:0,0-0' does not support environments
```

Fix: add a `define "bundle" "environments"` child block to the bundle
(schema: only attribute `required`). **VERBATIM:**

```hcl
define "bundle" "environments" {
  required = true
}
```

### A.3 — With A.1 + A.2, fan-out works: one BundleInstance -> N stacks

**CORRECTED WORKING bundle** (reconstructed from the probe runs — the committed spike's echo bundle used the wrong `bundle.instance.name` form; the `pc` bundle in `/tmp/tm-spike` is the committed equivalent proving `bundle.environment.id`).

**VERBATIM WORKING BundleInstance** (`scaffold/echo.tm.yml`):

```yaml
apiVersion: terramate.io/cli/v1
kind: BundleInstance
metadata:
  name: echo
spec:
  source: /bundles/echo
  inputs:
    role: hub            # base inputs; overridden per-env below
environments:
  infra: { inputs: { role: hub } }
  dev:   { inputs: { role: spoke } }
  prd:   { inputs: { role: spoke } }
```

**VERBATIM WORKING bundle** (`bundles/echo/bundle.tm.hcl`) — note **how the
environment id is read: `bundle.environment.id`** (see A.4), which is what makes
the fan-out paths unique:

```hcl
define "bundle" "metadata" {
  class       = "echo"
  version     = "0.0.1"
  name        = "echo"
  description = "toy echo bundle"
}

define "bundle" "environments" {
  required = true
}

define "bundle" {
  input "role" {
    type        = string
    description = "role"
    default     = "hub"
  }

  scaffolding {
    path = "/stacks/echo"
    name = "echo"
  }
}

define bundle stack "main" {
  metadata {
    path        = "/stacks/${bundle.environment.id}/echo"
    name        = "echo-${bundle.environment.id}"
    description = "echo stack for ${bundle.environment.id}"
    tags        = ["echo"]
  }

  component "echoer" {
    source = "/components/echoer"
    inputs {
      role = bundle.input.role.value
    }
  }
}
```

`scaffolding {}` note: used by `terramate scaffold` for interactive instance creation; it does not affect `terramate generate` output — safe to include for scaffold support or omit.

**Result of `terramate generate` (verbatim):**

```
Code generation report
Successes:
- /stacks/dev/echo
	[+] out.txt
	[+] stack.tm.hcl
- /stacks/infra/echo
	[+] out.txt
	[+] stack.tm.hcl
- /stacks/prd/echo
	[+] out.txt
	[+] stack.tm.hcl
```

(out.txt files were generated during the probe but not committed to the spike repo.)

**Generated path convention:** whatever you put in the stack `metadata.path`.
It is NOT auto-namespaced by env — YOU must include `${bundle.environment.id}`
in the path or the three env instances collide. We used
`/stacks/<env-id>/<name>`.

**Per-env input override confirmed** — `out.txt` contents:

```
stacks/infra/echo/out.txt -> role=hub
stacks/dev/echo/out.txt   -> role=spoke
stacks/prd/echo/out.txt   -> role=spoke
```

### A.4 — Reading the current environment inside the bundle

Probed several expressions; **`bundle.environment.id` is the answer.**

| expression | result |
|---|---|
| `bundle.environment.id` | **works** (string) |
| `bundle.environment.name` | works (string) |
| `bundle.environment` | object (`string required, but have object`) — has children `id`, `name` (`.NOPE` -> "does not have attribute NOPE") |
| `environment` / `environment.id` | `There is no variable named "environment"` |
| `terramate.stack.*` | `This object does not have an attribute named "stack"` |
| `bundle.env` | `This object does not have an attribute named "env"` |

Also useful: `bundle.input.<name>.value`, `component.input.<name>.value`, and
`bundle.class` all resolve. `bundle.name`, `bundle.version`, `bundle.description`,
`bundle.instance`, `bundle.metadata` do **NOT** exist. **There is no
`bundle.instance.name`** (the exemplar syntax in the plan context is wrong on
this) — derive stack paths/names from `bundle.environment.id` + literals, not
from an instance name.

**DECISION GATE (from the brief) result:** `environments:` **is supported on
GA** → we take the *supported* path, NOT the fallback of one scaffold file per
env. Later tasks: one `.tm.yml` per bundle instance with an `environments:` map;
the bundle opts in via `define "bundle" "environments" { required = true }`;
per-env differences go under `environments.<id>.inputs`. An explicit env input
is not needed for the id — use `bundle.environment.id`.

---

## B. Run ordering (`after`) — **WORKS in `define bundle stack` metadata, incl. cross-instance**

### B.1 — `metadata {}` schema of `define bundle stack`

Enumerated (bogus-attr probe):

```
> valid attributes are [after, before, description, name, path, tags, wanted_by, wants, watch] but found "BOGUS"
```

So `after` **and** `before` (and `wants`/`wanted_by`/`watch`) are all valid.
**There is NO `id` attribute** — you cannot set a deterministic stack id from
the stack metadata (see B.3 / C).

### B.2 — `after` produces correct run-order (verbatim)

Two stacks in one bundle, consumer `after` producer:

```hcl
define bundle stack "consumer" {
  metadata {
    path        = "/stacks/${bundle.environment.id}/consumer"
    name        = "consumer-${bundle.environment.id}"
    description = "consumer"
    tags        = ["consumer"]
    after       = ["/stacks/${bundle.environment.id}/producer"]
  }
  ...
}
```

`terramate generate && terramate list --run-order` (verbatim):

```
stacks/dev/producer
stacks/infra/producer
stacks/prd/producer
stacks/dev/consumer
stacks/infra/consumer
stacks/prd/consumer
```

All producers precede all consumers. **Cross-instance edges work too:** a
second bundle (`hub`) + `after = ["/stacks/${bundle.environment.id}/hub"]` on the
`pc` bundle's producer gave, verbatim:

```
stacks/dev/hub
stacks/infra/hub
stacks/prd/hub
stacks/dev/producer
stacks/infra/producer
stacks/prd/producer
stacks/dev/consumer
stacks/infra/consumer
stacks/prd/consumer
```

(This fixture is committed in the spike repo at `/tmp/tm-spike`.)

**`after` takes absolute repo paths** (`/stacks/...`), and those resolve
regardless of which bundle generated the target stack. Relative-path `after`
also parses; **prefer absolute** for cross-instance clarity. This is exactly the
hub->spoke ordering the design needs.

### B.3 — LOAD-BEARING CAVEAT: `after` is NOT persisted into the stack dir

The generated `stack.tm.hcl` contains **only the auto-UUID `id`** — NOT the
`name`/`tags`/`after`/`description` from the define block:

```hcl
# stacks/dev/consumer/stack.tm.hcl  (the WHOLE file)
stack {
  id = "9a2d912f-bfa6-4aca-9ea4-14eaa883e65a"
}
```

Terramate re-derives ordering/name/tags from the `define bundle stack` block at
graph-computation time. **Proof:** with the bundle/component/scaffold files
temporarily moved out, `terramate list --run-order` **lost the ordering**
(consumer sorted alphabetically before producer). Implication for **CI and
orchestration**: the bundle + component + `.tm.yml` sources must be present in
the repo checkout for `terramate list --run-order` (and any ordered
`terramate run`) to honor `after`. For this in-repo monorepo showcase that is
always true, so it's a documentation note, not a blocker. Do NOT try to make a
component emit `stack { after = [...] }` into the stack dir — it collides with
the auto stack block (see C — "duplicated stack blocks across configs").

**Fallback (not needed):** the object-layer `generate_hcl` emitting a `stack {}`
was tested and FAILS with duplicate-stack-block; ordering-via-CI-only was not
needed. Ordering via `define bundle stack metadata.after` is the mechanism.

---

## C. Greenfield cross-stack value passing — **WORKS via outputs-sharing + component-generated blocks + `--mock-on-fail`**

The decisive test passed: **`tofu plan` on a consumer whose producer was NEVER
applied succeeds, satisfied by the mock.**

### C.1 — Root `sharing_backend` (schema: `type`,`command`,`filename` all required)

**VERBATIM WORKING** (at repo root, e.g. `sharing.tm.hcl`; needs
`experiments = ["outputs-sharing"]` in `terramate.config`):

```hcl
sharing_backend "default" {
  type     = terraform                # bareword, not a string
  command  = ["tofu", "output", "-json"]
  filename = "_tmgen-sharing.tf"
}
```

### C.2 — Components CAN generate the `output`/`input` sharing blocks (two-pass)

**YES to the brief's key question (1):** a component emits `.tm.hcl` containing
the sharing blocks, and a **second `terramate generate` pass** reads them and
materializes the `variable`/`output` into `_tmgen-sharing.tf`. Confirmed
generation converges (idempotent) by pass 3.

**Producer component** (`components/producer/component.tm.hcl`) — VERBATIM:

```hcl
define "component" "metadata" {
  class       = "producer"
  version     = "0.0.1"
  name        = "producer"
  description = "produces a shared value"
}

define "component" {
}

generate_hcl "_producer.tf" {
  content {
    resource "terraform_data" "p" {
      input = "produced-value"
    }
  }
}

# Terramate sharing OUTPUT block, emitted into the stack.
generate_hcl "_tmgen-output.tm.hcl" {
  content {
    output "shared_val" {
      backend = "default"
      value   = terraform_data.p.output
    }
  }
}
```

**Consumer component** (`components/consumer/component.tm.hcl`) — VERBATIM:

```hcl
define "component" "metadata" {
  class       = "consumer"
  version     = "0.0.1"
  name        = "consumer"
  description = "consumes a shared value"
}

define "component" {
  input "producer_id" {
    type        = string
    description = "stack id (UUID) of the producer whose output we consume"
  }
}

# Terramate sharing INPUT block, emitted into the stack. `mock` satisfies
# greenfield `tofu plan` when the producer has never been applied.
generate_hcl "_tmgen-input.tm.hcl" {
  content {
    input "shared_val" {
      backend       = "default"
      from_stack_id = component.input.producer_id.value
      value         = outputs.shared_val.value
      mock          = "MOCKED-VALUE"
    }
  }
}

generate_hcl "_consumer.tf" {
  content {
    resource "terraform_data" "c" {
      input = var.shared_val
    }
  }
}
```

**Sharing block schemas (CORRECTED — the exemplar/plan is wrong here):**

- `output` block: attributes `backend` (backend name) + `value` (expression).
  The plan-context assumption is fine.
- `input` block: `backend`, `from_stack_id`, `value` (= `outputs.<name>.value`),
  `mock`. **There is NO `name` attribute** on the sharing `input` block — the
  block's *label* is the shared name. Attempting `name = "shared_val"` fails:
  ```
  > unrecognized attribute name
  > attribute "input.value" is required
  ```
  The block's label (`input "shared_val"`) also names the generated
  `variable "shared_val"`. `value = outputs.shared_val.value` is required (it
  is the expression that reads the upstream output at apply).

**Two-pass generation (verbatim second pass):**

```
# pass 2 output
	[+] _tmgen-sharing.tf        (consumer: variable "shared_val")
	[+] _tmgen-sharing.tf        (producer: output "shared_val")
# pass 3: no changes (idempotent / converged)
```

Generated materializations (verbatim):

```hcl
# stacks/<env>/consumer/_tmgen-sharing.tf
variable "shared_val" {
  type = any
}
# stacks/<env>/producer/_tmgen-sharing.tf
output "shared_val" {
  value = terraform_data.p.output
}
```

### C.3 — `from_stack_id` accepts the producer's **auto-UUID**; there is no deterministic id

**Brief's key question (2):** `from_stack_id` takes the producer stack's
`stack.id`. Bundle-generated stacks get an **auto-UUID** written into
`stack.tm.hcl`; **you cannot set a deterministic id** — `define bundle stack
metadata` has no `id` attr, and a component-emitted `stack { id = ... }` collides:

```
> duplicated stack blocks across configs
```

**Working pattern (matches the production tofumate repo):** the producer keeps
its auto-UUID; the consumer's `from_stack_id` is wired **per-environment via the
`.tm.yml`** (a bundle input that flows to `component.input.producer_id.value`).
Because each env's producer gets a distinct UUID, the id MUST be set under
`environments.<id>.inputs`, not once at the top:

```yaml
apiVersion: terramate.io/cli/v1
kind: BundleInstance
metadata:
  name: pc
spec:
  source: /bundles/pc
environments:
  infra: { inputs: { producer_stack_id: "796d0584-94d6-448d-8f13-d408ad7d7b29" } }
  dev:   { inputs: { producer_stack_id: "e40e0f16-7716-4ee5-a256-2b4a19b96362" } }
  prd:   { inputs: { producer_stack_id: "cb2fd6b0-6083-4a49-850c-7a798f2aefb8" } }
```

Verified each env's generated consumer `_tmgen-input.tm.hcl` got its own env's
producer UUID. **Design consequence (important for later tasks):** the producer
UUIDs are only known *after* the first `terramate generate` writes each
`stacks/<env>/producer/stack.tm.hcl`. So the wiring is a **two-step author
flow**: (1) generate to mint the producer UUIDs, (2) read them from
`stack.tm.hcl` and write them into the consumer instance's per-env inputs, (3)
regenerate. This is exactly how tofumate does it (`network_stack_id` read from
the network child's `stack.tm.hcl` and set on the spoke `.tm.yml`). Bake this
into the eks-cluster bundle scaffolding step. (Same-bundle producer+consumer:
the producer child's UUID still isn't knowable at generate time, so this
mint-then-wire step is unavoidable — plan for it.)

### C.4 — DECISIVE greenfield test: `tofu plan` with producer never applied

CI/preview incantation (this is what Task 12's CI must run for previews):

```
terramate run --enable-sharing --mock-on-fail -C <consumer-stack> -- tofu plan
```

**VERBATIM (producer NEVER applied, consumer greenfield plan):**

```
terramate: Entering stack in /stacks/dev/consumer
terramate: Executing command "tofu plan -no-color"
...
  # terraform_data.c will be created
  + resource "terraform_data" "c" {
      + id     = (known after apply)
      + input  = "MOCKED-VALUE"
      + output = (known after apply)
    }
Plan: 1 to add, 0 to change, 0 to destroy.
```

Exit 0. The **mock satisfied the greenfield plan**.

Flag behavior (documented so CI uses the right flags):

- `--enable-sharing` **alone**, greenfield -> FAILS:
  `eval expression: evaluating input value: This object does not have an attribute named "shared_val".`
- plain `terramate run` (no sharing flags) -> the generated `variable
  "shared_val"` is undefined: `No value for required variable`.
- `--enable-sharing --mock-on-fail` -> mock injected, plan succeeds. **Use both
  for greenfield previews.**

### C.5 — Full lifecycle: real value flows after apply (no AWS creds anywhere)

After `terramate run -C stacks/dev/producer -- tofu apply -auto-approve` (local
`terraform_data`, no AWS), the consumer plan with `--enable-sharing` (no
`--mock-on-fail` needed) reads the REAL value, verbatim:

```
  # terraform_data.c will be created
  + resource "terraform_data" "c" {
      + input  = "produced-value"
      ...
```

So: greenfield -> `mock`; post-apply -> real upstream output. End-to-end
outputs-sharing confirmed.

**DECISION (brief unknown C):** WINNER = **Terramate outputs-sharing, blocks
generated by components, consumed with `--enable-sharing --mock-on-fail` for
previews.** The tag-based `data aws_*` fallback is NOT needed. Tasks 5–10 emit
`output`/`input` sharing blocks from components as shown; the consumer's
`from_stack_id` is wired per-env in the `.tm.yml` (C.3). **Footgun (from the
production repo, carry forward):** a `mock` is only safe when consumed by a
provider config or a resource argument — the moment a mock feeds a **live
data-source lookup** (`data aws_vpc`/`aws_security_group`/`aws_eks_cluster` by a
mocked name/tag), it triggers a real AWS query for a nonexistent thing and fails
at plan. Consume shared ids as `var.*` in resource/provider args, never as a
data-source filter.

---

## Secondary syntax answers (de-risking later tasks)

- **Does `define bundle stack` metadata accept `after`?** YES (B.1/B.2). Also
  `before`, `wants`, `wanted_by`, `watch`.
- **Does it accept an `id`?** NO. No `id` attribute; stacks get an auto-UUID
  in `stack.tm.hcl`. Deterministic ids are impossible (duplicate-block error).
  Wire producer UUIDs per-env via `.tm.yml` (C.3).
- **Can a component's generate block emit `.tm.hcl` (Terramate config) into the
  stack, and does a 2nd `terramate generate` pass pick it up?** YES — this is
  exactly how the sharing `input`/`output` blocks work (C.2). Generation
  converges (idempotent) by ~pass 3. **Naming:** component-generated files are
  prefixed `component_<component-name>__<file>` (e.g.
  `component_consumer__tmgen-input.tm.hcl`); the sharing backend's own output is
  the unprefixed `_tmgen-sharing.tf`.
- **How does the bundle read the current environment id?**
  `bundle.environment.id` (A.4). `bundle.environment.name` also exists.
  `environment.*`, `terramate.stack.*`, `bundle.env`, `bundle.instance.*` do NOT.
- **Component `define`:** only child block allowed is `metadata`; inputs are
  `define "component" { input "x" {...} }`; read as `component.input.x.value`.
- **Idempotency:** `terramate generate` is idempotent once converged (re-run
  reports 0 created/changed).

---

## Implications for the plan (assumptions to correct downstream)

1. **`environment "id" {}` labeled blocks are WRONG.** Use unlabeled
   `environment { id = "infra" ... }`. (Task 1 root config.)
2. **A bundle must opt into environments:** `define "bundle" "environments" {
   required = true }`, else the `.tm.yml` `environments:` key errors. (Tasks 4,
   11 bundles.)
3. **`bundle.instance.name` does NOT exist.** Build stack paths/names from
   `bundle.environment.id` + literals. Any exemplar using `bundle.instance.*`
   must be rewritten. (Tasks 4, 11.)
4. **The sharing `input` block has no `name` attribute** — the block label is
   the shared name, and `value = outputs.<label>.value` is required. Correct any
   generated `input {}` accordingly. (Tasks 5–10.)
5. **No deterministic stack ids.** Cross-stack `from_stack_id` must be wired
   per-environment in the `.tm.yml` from the producer's auto-UUID, in a
   mint-generate-then-wire-then-regenerate flow. Design the eks-cluster
   scaffolding step to do this. (Tasks 5–11.)
6. **Ordering lives in the `define bundle stack` block, not in the stack dir** —
   keep bundle/component sources in the repo for `--run-order` to work; use
   absolute-path `after` for hub->spoke edges. (Tasks 11, 12.)
7. **CI preview command is `terramate run --enable-sharing --mock-on-fail -- tofu
   plan`** (both flags). Apply/real-value runs use `--enable-sharing` alone.
   (Task 12 CI.)
8. **Mock footgun:** never let a shared `mock` value feed a live `data.aws_*`
   lookup; consume shared values only as provider/resource args. (Tasks 5–10.)
9. **Root `terramate.config.experiments = ["outputs-sharing"]`** is required for
   sharing; `sharing_backend "default"` needs `type`/`command`/`filename`.
   (Task 1 root, Task 3 backend.)
