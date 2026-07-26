#!/usr/bin/env bash
set -euo pipefail

session="${1:-}"
socket_path="${2:-}"
[ -n "$session" ] || exit 1

tmux_cmd=(tmux)
if [ -n "$socket_path" ]; then
  tmux_cmd=(tmux -S "$socket_path")
fi

pid_file=$(mktemp)
cleanup() {
  rm -f "$pid_file"
}
trap cleanup EXIT

collect_process_tree() {
  local pid="$1"
  local child

  printf '%s\n' "$pid" >> "$pid_file"
  while IFS= read -r child; do
    [ -n "$child" ] || continue
    collect_process_tree "$child"
  done < <(pgrep -P "$pid" 2>/dev/null || true)
}

pane_pids=$("${tmux_cmd[@]}" list-panes -s -t "$session" -F '#{pane_pid}' 2>/dev/null || true)
while IFS= read -r pid; do
  [ -n "$pid" ] || continue
  collect_process_tree "$pid"
done <<< "$pane_pids"

pids=$(sort -u "$pid_file" 2>/dev/null || true)

set +e
"${tmux_cmd[@]}" kill-session -t "$session" 2>/dev/null || true

sleep 0.5

while IFS= read -r pid; do
  [ -n "$pid" ] || continue
  kill -KILL "$pid" 2>/dev/null || true
done <<< "$pids"
