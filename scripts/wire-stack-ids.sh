#!/usr/bin/env bash
# Mint-then-wire step 2: read the stack UUIDs Terramate minted into
# stacks/aws/<env>/eks/{network,cluster}/stack.tm.hcl and write them back into
# _scaffold-cluster.tm.yml as the *_stack_id inputs that outputs-sharing needs
# for from_stack_id.  Idempotent: existing *_stack_id keys are replaced.
#
# Usage: scripts/wire-stack-ids.sh   (from the repo root, after `make generate`)
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

scaffold="_scaffold-cluster.tm.yml"
[[ -f $scaffold ]] || { echo "error: $scaffold not found (run from the repo root)" >&2; exit 1; }

uuid_re='[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'

stack_id() { # <env> <stack>
  local f="stacks/aws/$1/eks/$2/stack.tm.hcl"
  [[ -f $f ]] || { echo "error: $f missing — run 'make generate' first" >&2; exit 1; }
  grep -oE "$uuid_re" "$f" | head -1
}

# Environments are whatever the bundle actually minted; the hub is the env whose
# provisioning stack got the argocd-hub component.
envs=()
hub_env=""
for d in stacks/aws/*/eks/network; do
  [[ -d $d ]] || continue
  e="$(basename "$(dirname "$(dirname "$d")")")"
  envs+=("$e")
  compgen -G "stacks/aws/$e/eks/provisioning/component_argocd-hub__*" >/dev/null && hub_env="$e"
done
[[ ${#envs[@]} -gt 0 ]] || { echo "error: no generated cluster stacks — run 'make generate' first" >&2; exit 1; }
[[ -n $hub_env ]] || { echo "error: no hub environment found (no argocd-hub component in any provisioning stack)" >&2; exit 1; }

hub_cluster_id="$(stack_id "$hub_env" cluster)"

# Build "env<TAB>key: value..." wiring lines, then splice them in with awk.
wiring=""
for e in "${envs[@]}"; do
  line="      network_stack_id: \"$(stack_id "$e" network)\"\n      cluster_stack_id: \"$(stack_id "$e" cluster)\""
  [[ $e != "$hub_env" ]] && line="$line\n      hub_cluster_stack_id: \"$hub_cluster_id\""
  wiring+="$e"$'\t'"$line"$'\n'
done

printf '%s' "$wiring" > /tmp/tm-wiring.$$
awk -v wiringfile="/tmp/tm-wiring.$$" '
  BEGIN {
    while ((getline l < wiringfile) > 0) { split(l, p, "\t"); w[p[1]] = p[2] }
  }
  /^environments:[[:space:]]*$/ { inenv = 1; print; next }
  inenv && /^  [A-Za-z0-9_-]+:[[:space:]]*$/ { env = $1; sub(/:$/, "", env); print; next }
  inenv && /^[^[:space:]]/ { inenv = 0; env = "" }
  inenv && env != "" && /^      (network|cluster|hub_cluster)_stack_id:/ { next }
  inenv && env != "" && /^    inputs:[[:space:]]*$/ {
    print
    if (env in w) { gsub(/\\n/, "\n", w[env]); print w[env] }
    next
  }
  { print }
' "$scaffold" > "$scaffold.tmp" && mv "$scaffold.tmp" "$scaffold"
rm -f /tmp/tm-wiring.$$

echo "wired stack ids into $scaffold (hub: $hub_env)"
grep -nE '_stack_id:' "$scaffold"
