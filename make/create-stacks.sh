#!/usr/bin/env bash
# Create (or correct) each stack's stack.tm.hcl with its derived id.
#
# The id is a pure function of the stack path -- see make/stack-ids.sh -- so this
# is idempotent and can run BEFORE the first `terramate generate`. That is the
# whole point: Terramate only mints a random UUID when stack.tm.hcl does not
# already exist, so seeding the file first means the ids are ours, deterministic,
# and knowable to the bundles without any wiring step.
#
# Usage: make/create-stacks.sh [--check]
#   --check  report what would change and exit 1 if anything would; write nothing
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

check_only=0
[[ ${1:-} == --check ]] && check_only=1

uuid_re='^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
created=0 corrected=0 ok=0

while read -r id path; do
  dir="${path#/}"
  file="$dir/stack.tm.hcl"

  if [[ -f $file ]]; then
    current="$(sed -n 's/^[[:space:]]*id[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' "$file" | head -1)"
    if [[ $current == "$id" ]]; then
      ok=$((ok + 1))
      continue
    fi
    if [[ $check_only == 1 ]]; then
      echo "would correct $path: $current -> $id"
      corrected=$((corrected + 1))
      continue
    fi
    # Changing an id changes that stack's S3 state key (stacks/by-id/<id>/...).
    # Harmless before the first apply; orphans existing state after one.
    if [[ $current =~ $uuid_re ]]; then
      echo "correcting $path: minted UUID -> $id (state key changes)"
    else
      echo "correcting $path: $current -> $id (state key changes)"
    fi
    corrected=$((corrected + 1))
  else
    [[ $check_only == 1 ]] && { echo "would create $path with id $id"; created=$((created + 1)); continue; }
    echo "creating $path with id $id"
    created=$((created + 1))
  fi

  mkdir -p "$dir"
  printf 'stack {\n  id = "%s"\n}\n' "$id" > "$file"
done < <(make/stack-ids.sh list)

if [[ $check_only == 1 ]]; then
  if (( created + corrected > 0 )); then
    echo "stack ids are out of date: $created to create, $corrected to correct" >&2
    exit 1
  fi
  echo "stack ids up to date ($ok stacks)"
  exit 0
fi

echo "stack ids: $created created, $corrected corrected, $ok already correct"
