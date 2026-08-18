#!/usr/bin/env bash
# Extract the k3s admin client cert/key/CA that MiniStack's EKS emulation creates,
# into .ministack/<cluster>.{crt,key,ca}.
#
# Why: `aws eks get-token` returns a well-formed ExecCredential but MiniStack's
# k3s has no aws-iam-authenticator webhook in front of it and answers 401. The
# k3s admin client certificate is the only way in, so the kubernetes/helm
# providers read these files for local envs (components/providers/kubernetes).
#
# Run after the cluster stack applies, before the provisioning stack (ci-hub, or
# a future ci-spoke — pass that cluster's name).
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

cluster="${1:-}"
[[ -n $cluster ]] || { echo "usage: ${BASH_SOURCE[0]##*/} <cluster-name>" >&2; exit 2; }

container="$(docker ps --format '{{.Names}}' | grep -E "ministack-eks-.*-${cluster}\$" | head -1 || true)"
[[ -n $container ]] || {
  echo "error: no k3s container for cluster '$cluster'." >&2
  echo "       Apply the cluster stack first, and make sure ministack was started" >&2
  echo "       with the docker socket mounted (make ci-up)." >&2
  exit 1
}

mkdir -p .ministack
tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
docker exec "$container" cat /etc/rancher/k3s/k3s.yaml > "$tmp"

python3 - "$tmp" "$cluster" <<'PY'
import base64, sys, yaml
cfg = yaml.safe_load(open(sys.argv[1])); cluster = sys.argv[2]
user = cfg["users"][0]["user"]
for field, ext in (("client-certificate-data", "crt"), ("client-key-data", "key")):
    open(f".ministack/{cluster}.{ext}", "wb").write(base64.b64decode(user[field]))
open(f".ministack/{cluster}.ca", "wb").write(
    base64.b64decode(cfg["clusters"][0]["cluster"]["certificate-authority-data"]))
PY

chmod 600 .ministack/"$cluster".key
echo "wrote .ministack/${cluster}.{crt,key,ca} from $container"
