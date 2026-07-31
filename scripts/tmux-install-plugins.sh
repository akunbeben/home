#!/usr/bin/env bash
set -euo pipefail

plugin_dir="${TMUX_PLUGIN_MANAGER_PATH:-$HOME/.tmux/plugins}"
mkdir -p "$plugin_dir"

install_plugin() {
  local name="$1"
  local repo="$2"
  local commit="$3"
  local dir="$plugin_dir/$name"
  local current

  if [ ! -d "$dir/.git" ]; then
    git clone --filter=blob:none --no-checkout "$repo" "$dir"
  fi

  current=$(git -C "$dir" rev-parse HEAD 2>/dev/null || true)
  if [ "$current" != "$commit" ]; then
    git -C "$dir" fetch --depth=1 origin "$commit"
    git -C "$dir" checkout --detach "$commit"
  fi
}

install_plugin tpm \
  https://github.com/tmux-plugins/tpm.git \
  99469c4a9b1ccf77fade25842dc7bafbc8ce9946
install_plugin tmux-sensible \
  https://github.com/tmux-plugins/tmux-sensible.git \
  25cb91f42d020f675bb0a2ce3fbd3a5d96119efa
install_plugin tmux-resurrect \
  https://github.com/tmux-plugins/tmux-resurrect.git \
  cff343cf9e81983d3da0c8562b01616f12e8d548
install_plugin tmux-nerd-font-window-name \
  https://github.com/joshmedeski/tmux-nerd-font-window-name.git \
  0af812a228e1b9f538b8d220c6c59d82d7228973
