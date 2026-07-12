#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: privacy-mirror-move <workspace>" >&2
  exit 1
fi

aerospace=$(command -v aerospace || true)
if [ -z "$aerospace" ] && [ -x /opt/homebrew/bin/aerospace ]; then
  aerospace=/opt/homebrew/bin/aerospace
fi
if [ -z "$aerospace" ]; then
  echo "Error: aerospace command not found" >&2
  exit 1
fi

socket="/tmp/privacy-mirror-$(id -u).sock"
if [ -S "$socket" ]; then
  response=$(printf 'invalidate\n' | /usr/bin/nc -U -w 2 "$socket")
  if [ "$response" != "ok" ]; then
    echo "Error: Privacy Mirror did not acknowledge a safe transition" >&2
    exit 1
  fi
fi

exec "$aerospace" move-node-to-workspace "$1" --focus-follows-window
