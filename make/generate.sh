#!/usr/bin/env bash
# make generate — two-pass code generation, self-bootstrapping for new environments.
#
# The account map (bundles/*/_tmgen-input-account-map.tm.hcl) is a GENERATED
# bundle input that the hand-written `define bundle stack` tags read at parse
# time. When you add or rename an environment, config.tm.hcl declares it before
# the generated map knows about it -- and then *every* terramate command fails to
# parse ("key does not identify an element"). terramate cannot seed the map
# because it cannot parse the config, so we break the cycle here: seed a throwaway
# placeholder entry for any env the map is missing, then let the first real
# `terramate generate` pass overwrite the whole map with canonical values and the
# second materialise the sharing .tf files.
#
# On an in-sync tree this seeds nothing and is just the two-pass generate.
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

MAP_FILES=(
  bundles/account-bootstrap/_tmgen-input-account-map.tm.hcl
  bundles/eks-cluster/_tmgen-input-account-map.tm.hcl
)

# Environments the scaffolds expect. Parsed WITHOUT terramate: when the map is
# behind config terramate cannot parse, so we cannot ask it (make/stack-ids.sh
# reads the scaffolds directly).
want="$(make/stack-ids.sh envs | awk '{for (i = 3; i <= NF; i++) print $i}' | sort -u)"

# A structurally-complete placeholder so config parses and the first pass can run;
# every field the bundles read is present. Real values come from the overwrite.
placeholder_block() { # $1 = env id
  cat <<EOF
      $1 = {
        account_id      = "000000000000"
        cluster_name    = "bootstrap-placeholder"
        deploy_role_arn = "bootstrap-placeholder"
        endpoint        = ""
        lock_table      = "bootstrap-placeholder"
        region          = "us-east-1"
        state_bucket    = "bootstrap-placeholder"
      }
EOF
}

skeleton() { # a fresh map file with every wanted env as a placeholder
  printf '// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT\n\n'
  printf 'define "bundle" {\n  input "aws_account_map" {\n    default = {\n'
  while IFS= read -r e; do [[ -n $e ]] && placeholder_block "$e"; done <<<"$want"
  printf '    }\n  }\n}\n'
}

seeded=0
for f in "${MAP_FILES[@]}"; do
  if [[ ! -f $f ]]; then
    echo "bootstrap: $f absent -- seeding placeholders for all envs"
    mkdir -p "$(dirname "$f")"
    skeleton >"$f"
    seeded=1
    continue
  fi
  present="$(grep -oE '^      [A-Za-z0-9_-]+ = \{' "$f" | sed -E 's/ *= \{$//; s/ //g' | sort -u)"
  missing="$(comm -23 <(printf '%s\n' "$want") <(printf '%s\n' "$present"))"
  [[ -z ${missing//[[:space:]]/} ]] && continue
  printf 'bootstrap: seeding %s for: %s\n' "$f" "$(echo "$missing" | tr '\n' ' ')"
  tmp="$(mktemp)"
  while IFS= read -r e; do [[ -n $e ]] && placeholder_block "$e"; done <<<"$missing" >"$tmp"
  # inject the placeholder(s) immediately after the `    default = {` line
  sed -i "/^    default = {$/r $tmp" "$f"
  rm -f "$tmp"
  seeded=1
done

[[ $seeded == 1 ]] && echo "bootstrap: seeded; the two generate passes below overwrite the map with canonical values"

# two passes: object-layer _tmgen inputs (incl. the real account map), then bundle stacks
terramate generate
terramate generate
