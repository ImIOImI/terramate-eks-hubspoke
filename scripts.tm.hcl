# ---------------------------------------------------------------------------
# Terramate Scripts (https://terramate.io/docs/cli/orchestration/scripts).
#
# `deploy` replaces hand-rolled tier loops: Terramate runs every job of the
# script for one stack before moving to the next, in the stack graph's order
# (bootstrap -> network -> cluster -> nodes -> provisioning, spokes after their
# hub). That per-stack init+apply is exactly what outputs-sharing needs: a
# producer is applied before any consumer is initialised.
#
#   terramate script run --tags env-dev deploy     # one environment
#   terramate script run --tags local deploy       # every MiniStack env
#
# Local (MiniStack) stacks get two extra steps, chosen per stack from its tags:
# start MiniStack before the first bootstrap, and pull the k3s certs + IP out
# of each cluster's container right after its cluster stack applies.
#
# The ci-only scripts (`ci argo`, `ci test`) are generated into the local
# provisioning stacks by the argocd-hub / argocd-spoke components, so they
# only exist (and only run) where they make sense.
# ---------------------------------------------------------------------------
script "deploy" {
  description = "init + apply each selected stack in dependency order (MiniStack-aware)"
  lets {
    tags    = terramate.stack.tags
    local   = tm_contains(terramate.stack.tags, "local")
    root    = terramate.root.path.fs.absolute
    env     = tm_element(tm_split("/", terramate.stack.path.absolute), 3)
    cluster = "${global.project_prefix}-eks-${tm_element(tm_split("/", terramate.stack.path.absolute), 3)}"
  }
  job {
    name = "apply"
    commands = tm_concat(
      let.local && tm_contains(let.tags, "bootstrap") ? [["${let.root}/make/ci-up.sh"]] : [],
      [
        ["tofu", "init", "-input=false", { enable_sharing = true }],
        ["tofu", "apply", "-input=false", "-auto-approve", { enable_sharing = true }],
      ],
      let.local && tm_contains(let.tags, "cluster") ? [["${let.root}/make/ci-kubeconfig.sh", let.cluster]] : [],
    )
  }
}
