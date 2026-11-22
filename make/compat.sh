#!/usr/bin/env bash
# make compat TM=<ver> TOFU=<ver> AWS=<ver> [MODE=validate|apply]
#
# Toolchain compatibility check for one Terramate / OpenTofu / AWS-provider
# combination. Runs in a throwaway git worktree of HEAD, so your checkout and
# the committed pins are never touched.
#
#   1. Downloads the requested terramate + tofu (checksum-verified, cached).
#   2. `make generate` with that terramate must reproduce the committed output
#      byte for byte.
#   3. Pins tofu_version and the aws provider to exactly the requested versions,
#      regenerates, and re-resolves only the aws entry in every lock file.
#   4. MODE=validate (default): validate every non-local stack.  MODE=apply: full `make apply ENV=ci-hub` against MiniStack (needs
#      Docker), then tears the local fabric down.
#
# Exit 0 = combination works. Results are documented in docs/TOOLCHAIN.md.
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

TM="${TM:?set TM=<terramate version>}"
TOFU="${TOFU:?set TOFU=<opentofu version>}"
AWS="${AWS:?set AWS=<aws provider version>}"
MODE="${MODE:-validate}"
CACHE="${COMPAT_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/terramate-eks-hubspoke/compat}"
mkdir -p "$CACHE/bin" "$CACHE/plugins"

case "$(uname -s)" in Linux) os=linux ;; Darwin) os=darwin ;; *) echo "unsupported OS" >&2; exit 2 ;; esac
case "$(uname -m)" in
  x86_64 | amd64) tm_arch=x86_64 tofu_arch=amd64 ;;
  arm64 | aarch64) tm_arch=arm64 tofu_arch=arm64 ;;
  *) echo "unsupported arch" >&2; exit 2 ;;
esac

sha256() { if command -v sha256sum >/dev/null; then sha256sum "$1"; else shasum -a 256 "$1"; fi | cut -d' ' -f1; }

fetch() { # url sums-url asset-name dest
  curl -fsSL -o "$4" "$1"
  local want
  want="$(curl -fsSL "$2" | awk -v n="$3" '$2 == n || $2 == "*"n {print $1}')"
  [[ -n $want && $want == "$(sha256 "$4")" ]] || { echo "checksum mismatch for $3" >&2; exit 1; }
}

install_tools() {
  local tm_bin="$CACHE/bin/terramate-$TM" tofu_bin="$CACHE/bin/tofu-$TOFU" tmp
  tmp="$(mktemp -d)"
  if [[ ! -x $tm_bin ]]; then
    local n="terramate_${TM}_${os}_${tm_arch}.tar.gz" b="https://github.com/terramate-io/terramate/releases/download/v$TM"
    fetch "$b/$n" "$b/checksums.txt" "$n" "$tmp/$n"
    tar -xzf "$tmp/$n" -C "$tmp" terramate && mv "$tmp/terramate" "$tm_bin"
  fi
  if [[ ! -x $tofu_bin ]]; then
    local n="tofu_${TOFU}_${os}_${tofu_arch}.zip" b="https://github.com/opentofu/opentofu/releases/download/v$TOFU"
    fetch "$b/$n" "$b/tofu_${TOFU}_SHA256SUMS" "$n" "$tmp/$n"
    unzip -q "$tmp/$n" tofu -d "$tmp" && mv "$tmp/tofu" "$tofu_bin"
  fi
  rm -rf "$tmp"
  mkdir -p "$work_bin"
  ln -sf "$tm_bin" "$work_bin/terramate"
  ln -sf "$tofu_bin" "$work_bin/tofu"
}

label="terramate $TM / tofu $TOFU / aws $AWS ($MODE)"
wt="$(mktemp -d)/wt"
work_bin="$(dirname "$wt")/bin"
logs="$(dirname "$wt")"
cleanup() {
  if [[ $MODE == apply ]]; then (cd "$wt" 2>/dev/null && make ci-down >/dev/null 2>&1) || true; fi
  git -C "$repo_root" worktree remove --force "$wt" >/dev/null 2>&1 || true
  rm -rf "$(dirname "$wt")"
}
trap cleanup EXIT

fail() { echo "FAIL  $label: $*"; exit 1; }

install_tools
export PATH="$work_bin:$PATH" TF_PLUGIN_CACHE_DIR="$CACHE/plugins" TF_IN_AUTOMATION=1
git -C "$repo_root" worktree add -q --detach "$wt" HEAD
cd "$wt"
commit() { git add -A && git -c user.name=compat -c user.email=compat@localhost commit -qm "$1" --allow-empty; }

# 2. generation must be byte-identical with this terramate
make generate >"$logs/gen.log" 2>&1 || { tail -20 "$logs/gen.log"; fail "make generate"; }
[[ -z "$(git status --porcelain)" ]] || { git status --short | head; fail "generated output differs from the committed files"; }

# 3. pin exact tofu + aws, re-resolve only the aws lock entries
sed -i.bak -E "s/(tofu_version[[:space:]]*=[[:space:]]*)\"[^\"]+\"/\1\"$TOFU\"/" config.tm.hcl
sed -i.bak -E "s#(aws[[:space:]]*=[[:space:]]*\{[[:space:]]*source[[:space:]]*=[[:space:]]*\"hashicorp/aws\",[[:space:]]*version[[:space:]]*=[[:space:]]*)\"[^\"]+\"#\1\"= $AWS\"#" config.tm.hcl
rm -f config.tm.hcl.bak
grep -q "\"= $AWS\"" config.tm.hcl || fail "could not pin the aws provider in config.tm.hcl"
make generate >/dev/null 2>&1 || fail "make generate (pinned)"
for f in $(git ls-files '*.terraform.lock.hcl'); do
  awk 'BEGIN{skip=0} /^provider "registry\.opentofu\.org\/hashicorp\/aws" \{/{skip=1} skip&&/^\}/{skip=0; getline; next} !skip' "$f" >"$f.tmp" && mv "$f.tmp" "$f"
done
commit "compat pins" # terramate run refuses to run on uncommitted files
terramate run --quiet -- tofu init -backend=false -input=false -no-color >"$logs/lock.log" 2>&1 ||
  { grep -A8 'Error' "$logs/lock.log" | head -30; fail "tofu init (resolving aws $AWS)"; }
commit "compat locks"

# 4. exercise it
if [[ $MODE == validate ]]; then
  terramate run --quiet --no-tags local -- tofu validate -no-color >"$logs/validate.log" 2>&1 ||
    { grep -A8 'Error' "$logs/validate.log" | head -30; fail "tofu validate"; }
elif [[ $MODE == apply ]]; then
  make ci-down >/dev/null 2>&1 || true
  make ci-hub-apply >"$logs/apply.log" 2>&1 || { sed 's/\x1b\[[0-9;]*m//g' "$logs/apply.log" | grep -E '^>>|Error' | tail -15; fail "make ci-hub-apply"; }
else
  fail "unknown MODE=$MODE"
fi

echo "PASS  $label"
