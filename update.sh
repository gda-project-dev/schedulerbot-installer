#!/usr/bin/env bash
set -euo pipefail

IMAGE="ghcr.io/gda-project-dev/schedulerbot"
CONTAINER_NAME="${CONTAINER_NAME:-schedulerbot}"
VERSION=""
TOKEN="${GHCR_TOKEN:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version|-v) VERSION="$2"; shift 2 ;;
    --token) TOKEN="$2"; shift 2 ;;
    *) echo "Unknown argument $1"; exit 1 ;;
  esac
done

if [[ -z "$VERSION" ]]; then
  echo "❌ Missing --version"
  exit 1
fi

FULL_IMAGE="$IMAGE:$VERSION"

echo "⏫ Updating SchedulerBot → $VERSION"

if [[ -n "$TOKEN" ]]; then
  echo "🔐 Logging in..."
  echo "$TOKEN" | docker login ghcr.io -u gda-project-dev --password-stdin
fi

docker pull "$FULL_IMAGE"

docker stop "$CONTAINER_NAME" || true
docker rm "$CONTAINER_NAME" || true

docker run -d \
  --name "$CONTAINER_NAME" \
  -p 3067:3067 \
  -v /opt/schedulerbot/db:/app/social-scheduler-api/db \
  --restart unless-stopped \
  "$FULL_IMAGE"

echo "🎉 Updated to $FULL_IMAGE"
