#!/usr/bin/env bash
set -euo pipefail

session="${1:-}"
socket_path="${2:-}"
[ -n "$session" ] || exit 1

tmux_cmd=(tmux)
if [ -n "$socket_path" ]; then
  tmux_cmd=(tmux -S "$socket_path")
fi

exec "${tmux_cmd[@]}" kill-session -t "$session"
