#!/usr/bin/env bash
# Build the mini-swe-agent CVDP agent image.
set -euo pipefail
cd "$(dirname "$0")"

IMAGE_NAME="${IMAGE_NAME:-cvdp-mini-swe-agent}"

if ! docker image inspect nvidia/cvdp-sim:v1.0.0 >/dev/null 2>&1; then
  echo "Base image nvidia/cvdp-sim:v1.0.0 not found. Build it first:" >&2
  echo "  docker build -f docker/Dockerfile.sim -t nvidia/cvdp-sim:v1.0.0 ." >&2
  exit 1
fi

docker build -t "$IMAGE_NAME" "$@" .
echo "Built agent image: $IMAGE_NAME"
