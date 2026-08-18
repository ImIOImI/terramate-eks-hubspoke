#!/usr/bin/env bash
# Bring up MiniStack (https://ministack.org) for the local `ci` environment.
#
# The docker socket mount is REQUIRED: without it EKS is a control-plane stub and
# CreateCluster never spawns the k3s container the cluster stack needs.
set -euo pipefail

name="${MINISTACK_CONTAINER:-ministack}"
port="${MINISTACK_PORT:-4566}"
image="${MINISTACK_IMAGE:-ministackorg/ministack}"

if [[ -n "$(docker ps -q --filter "name=^${name}$")" ]]; then
  echo "ministack already running (container: $name)"
else
  docker rm -f "$name" >/dev/null 2>&1 || true
  echo "starting ministack on :$port ..."
  docker run -d --name "$name" -p "${port}:4566" \
    -v /var/run/docker.sock:/var/run/docker.sock "$image" >/dev/null
fi

for _ in $(seq 1 60); do
  status="$(docker inspect -f '{{.State.Health.Status}}' "$name" 2>/dev/null || echo starting)"
  [[ $status == healthy ]] && { echo "ministack healthy on http://localhost:${port}"; exit 0; }
  sleep 1
done

echo "error: ministack did not become healthy; try 'docker logs $name'" >&2
exit 1
