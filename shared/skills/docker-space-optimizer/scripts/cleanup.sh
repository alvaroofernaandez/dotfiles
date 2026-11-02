#!/usr/bin/env bash
# Safe Docker space cleanup for OrbStack: stopped containers, dangling images,
# build cache. Never touches volumes, tagged images or running containers.
set -euo pipefail

ORB_DATA="$HOME/Library/Group Containers/HUAQ24HBR6.dev.orbstack/data"

ctx="$(docker context show)"
if [ "$ctx" != "orbstack" ]; then
  echo "Refusing to prune: active docker context is '$ctx', expected 'orbstack'." >&2
  echo "Run: docker context use orbstack" >&2
  exit 1
fi

report() {
  echo "== $1 =="
  df -h / | tail -1
  du -sh "$ORB_DATA" 2>/dev/null || echo "OrbStack data dir not found: $ORB_DATA"
  docker system df
  echo
}

report BEFORE

docker container prune -f
docker image prune -f
docker builder prune -af

if orbctl --help 2>/dev/null | grep -qw compact; then
  orbctl compact
else
  echo "orbctl compact is not available: OrbStack's data.img is sparse and auto-shrinks after deletes."
fi
echo

report AFTER
