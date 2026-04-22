#!/usr/bin/env bash
# Bootstrap a new macOS machine.
# Run this ONCE before `nix run nix-darwin -- switch --flake ~/Projects/home#Macbook`

set -e

echo "==> Checking Homebrew..."
if ! command -v brew &>/dev/null; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Apple Silicon: add brew to PATH for the rest of this script
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  echo "Homebrew already installed."
fi

echo "==> Installing Nix (Determinate Systems)..."
if ! command -v nix &>/dev/null; then
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
    | sh -s -- install --no-confirm
  # Source nix for the rest of this script
  # shellcheck disable=SC1091
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
else
  echo "Nix already installed."
fi

echo "==> Running nix-darwin switch..."
nix run nix-darwin -- switch --flake ~/Projects/home#Macbook

echo "==> Running valet install..."
if command -v valet &>/dev/null; then
  valet install
else
  echo "  valet not found — run manually after brew installs complete"
fi

echo ""
echo "==> Done! Manual steps remaining:"
echo "  1. DankMono Nerd Font (WezTerm): purchase & install from https://dank.sh"
echo "  2. ssht hash: first rebuild will fail with the real hash — paste it into pkgs/ssht.nix"
echo "  3. Log out and back in so macOS picks up the new defaults"
