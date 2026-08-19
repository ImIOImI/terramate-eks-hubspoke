#!/usr/bin/env bash
# make apply ENV=<id> — stand one environment up end to end, tier by tier.
#
#   bootstrap -> network -> cluster -> [kubeconfig] -> nodes -> provisioning
#
# Tiering is mandatory: outputs-sharing cannot resolve a producer's outputs until
# that producer is applied, so a whole-chain `tofu init` fails up front.
#
# Real-AWS envs: run with your ambient admin creds. bootstrap (ambient creds)
# creates tmhs-deploy, trusts your caller, and its propagation gate waits until
# STS will honor the assume; the `after`-ordered eks tiers then assume the role.
# On the adopt path (deploy_role_arn set) there is no bootstrap stack — the tag
# matches nothing and the tier is skipped.
#
# Local (MiniStack) envs: brings MiniStack up first and extracts the k3s admin
# cert between cluster and nodes (the cert only exists once the cluster applies).
#
# Requires: terramate, tofu, and (real-AWS) the AWS CLI + ambient creds.
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

env="${1:-${ENV:-}}"
[[ -n $env ]] || {
  echo "usage: make apply ENV=<id>   (e.g. make apply ENV=dev, make apply ENV=ci-hub)" >&2
  exit 2
}

TM="terramate run --enable-sharing --tags"

# A MiniStack-backed env carries the `local` tag on its stacks.
is_local=0
[[ -n "$(terramate list --tags "env-$env" --tags local 2>/dev/null)" ]] && is_local=1

run_tier() { # $1 = tier label (bootstrap|network|cluster|nodes|provisioning)
  local sel="env-$env:$1"
  if [[ -z "$(terramate list --tags "$sel" 2>/dev/null)" ]]; then
    echo ">> no ${sel} stack — skipping"
    return 0
  fi
  echo ">> ${sel}: init"
  $TM "$sel" -- tofu init
  echo ">> ${sel}: apply"
  $TM "$sel" -- tofu apply -auto-approve
}

[[ $is_local == 1 ]] && ./make/ci-up.sh

run_tier bootstrap
run_tier network
run_tier cluster
[[ $is_local == 1 ]] && ./make/ci-kubeconfig.sh "tmhs-eks-${env}"
run_tier nodes
run_tier provisioning

echo "apply ENV=${env} complete"
