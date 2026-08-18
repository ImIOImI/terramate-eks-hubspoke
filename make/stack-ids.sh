#!/usr/bin/env bash
# Derive this repo's stack identity from source, with no calls to Terramate.
#
# For every root _scaffold-*.tm.yml it reads:
#   spec.source    -> the bundle directory
#   environments:  -> the environment ids that bundle fans out to
# and from that bundle's `define bundle stack "<label>" { metadata { path = ... } }`
# it reads the path template, substituting each environment id.
#
# The stack id is then a pure function of the stack path:
#
#     /stacks/aws/dev/eks/network  ->  dev-eks-network
#     /stacks/aws/dev/bootstrap    ->  dev-bootstrap
#
# i.e. strip $STACK_PREFIX and turn '/' into '-'. Paths are unique, so ids are
# unique by construction, and both the bundle and this script can compute the
# same id independently -- which is what lets bundles infer from_stack_id
# instead of taking it as a hand-wired input.
#
# Usage:
#   make/stack-ids.sh list     # print "<id> <path>" per stack (default)
#   make/stack-ids.sh envs     # print "<scaffold> <bundle> <env>..." per scaffold
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

STACK_PREFIX="${STACK_PREFIX:-/stacks/aws/}"

# id_for <stack path>
id_for() {
  local p="${1#"$STACK_PREFIX"}"
  p="${p#/}"
  printf '%s' "${p//\//-}"
}

# envs_of <scaffold file> -> environment ids, one per line
envs_of() {
  awk '
    /^environments:[[:space:]]*$/ { inenv = 1; next }
    inenv && /^[^[:space:]#]/     { inenv = 0 }
    # matches both block style ("  dev:") and flow style ("  dev: { inputs: {...} }")
    inenv && /^  [A-Za-z0-9_-]+:/ {
      key = $0; sub(/^[[:space:]]+/, "", key); sub(/:.*$/, "", key); print key
    }
  ' "$1"
}

# bundle_of <scaffold file> -> the bundle dir from spec.source
bundle_of() {
  awk '/^[[:space:]]*source:[[:space:]]*/ {
    sub(/^[[:space:]]*source:[[:space:]]*/, ""); gsub(/["\x27]/, ""); print; exit
  }' "$1"
}

# path_templates <bundle dir> -> the metadata.path of each `define bundle stack`
path_templates() {
  awk '
    /^define[[:space:]]+bundle[[:space:]]+stack[[:space:]]/ { instack = 1 }
    instack && /^[[:space:]]*path[[:space:]]*=/ {
      sub(/^[[:space:]]*path[[:space:]]*=[[:space:]]*/, ""); gsub(/"/, "")
      print; instack = 0
    }
  ' "$1"/*.tm.hcl
}

scaffolds() { ls -1 "$repo_root"/_scaffold-*.tm.yml 2>/dev/null | sort; }

cmd_envs() {
  local f
  for f in $(scaffolds); do
    printf '%s %s %s\n' "$(basename "$f")" "$(bundle_of "$f")" "$(envs_of "$f" | tr '\n' ' ')"
  done
}

cmd_list() {
  local f bundle env tmpl path
  for f in $(scaffolds); do
    bundle="$(bundle_of "$f")"
    [[ -d ${bundle#/} ]] || { echo "error: $(basename "$f") points at missing bundle $bundle" >&2; exit 1; }
    for env in $(envs_of "$f"); do
      while read -r tmpl; do
        [[ -n $tmpl ]] || continue
        path="${tmpl//\$\{bundle.environment.id\}/$env}"
        printf '%s %s\n' "$(id_for "$path")" "$path"
      done < <(path_templates "${bundle#/}")
    done
  done
}

case "${1:-list}" in
  list) cmd_list ;;
  envs) cmd_envs ;;
  *)    echo "usage: ${BASH_SOURCE[0]##*/} [list|envs]" >&2; exit 2 ;;
esac
