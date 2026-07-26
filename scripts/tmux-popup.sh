#!/usr/bin/env bash
set -euo pipefail

socket="quick-popup"
session="quick-popup"
config="$HOME/Projects/home/configs/tmux-popup.conf"
cwd="${1:-$HOME}"

exec env -u TMUX tmux -L "$socket" -f "$config" new-session -A -s "$session" -c "$cwd"
