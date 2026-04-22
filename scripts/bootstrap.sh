#!/usr/bin/env bash
# Bootstrap a new macOS machine.
# Run this ONCE before `nix run nix-darwin -- switch --flake ~/Projects/home#Macbook`

set -e

echo "==> Setting up SSH keys from Bitwarden..."
if ! command -v bw &>/dev/null; then
  echo "  bw CLI not found — install Bitwarden CLI first: brew install bitwarden-cli"
  exit 1
fi

BW_STATUS=$(bw status | python3 -c "import sys,json; print(json.load(sys.stdin)['status'])")
if [ "$BW_STATUS" = "unauthenticated" ]; then
  bw login
fi
if [ "$BW_STATUS" != "unlocked" ]; then
  export BW_SESSION=$(bw unlock --raw)
fi

mkdir -p ~/.ssh
chmod 700 ~/.ssh

bw get notes 6bfe68ff-2775-45dc-9d18-b43400e51209 > ~/.ssh/personal
bw get notes 8dc6a5f7-b7bb-4556-aae0-b43400e52bf6 > ~/.ssh/personal.pub
bw get notes e93686a1-fb28-4bc1-ab3c-b43400e53e61 > ~/.ssh/work
bw get notes 0ce6f34e-3349-422b-9f30-b43400e547b1 > ~/.ssh/work.pub

chmod 600 ~/.ssh/personal ~/.ssh/work
chmod 644 ~/.ssh/personal.pub ~/.ssh/work.pub
echo "  SSH keys restored."

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
echo "  1. ssht hash: first rebuild will fail with the real hash — paste it into pkgs/ssht.nix"
echo "  2. Log out and back in so macOS picks up the new defaults"
