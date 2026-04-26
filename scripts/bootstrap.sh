#!/usr/bin/env bash
# Bootstrap a new macOS machine.
# Run this ONCE on a fresh device.
#
# Prerequisites (do these manually before running):
#   1. GitHub repo akunbeben/home-private must exist (private config flake input)
#   2. Run this script: bash ~/Projects/home/scripts/bootstrap.sh

set -e

# --- 1. Homebrew ---
echo "==> Checking Homebrew..."
if ! command -v brew &>/dev/null; then
  echo "  Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  echo "  Homebrew already installed."
fi

# --- 2. Bitwarden CLI ---
echo "==> Checking Bitwarden CLI..."
if ! command -v bw &>/dev/null; then
  echo "  Installing bitwarden-cli..."
  brew install bitwarden-cli
fi

# --- 3. SSH keys from Bitwarden ---
echo "==> Restoring SSH keys from Bitwarden..."
BW_STATUS=$(bw status | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
if [ "$BW_STATUS" = "unauthenticated" ]; then
  bw login
  BW_STATUS="locked"
fi
if [ "$BW_STATUS" != "unlocked" ]; then
  read -r -s -p "  Bitwarden master password: " BW_PASSWORD
  echo
  export BW_PASSWORD
  export BW_SESSION=$(bw unlock --passwordenv BW_PASSWORD --raw)
  unset BW_PASSWORD
fi

mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Bitwarden strips the trailing newline from stored notes; private keys
# require it or ssh-add will reject them as invalid.
{ bw get notes 6bfe68ff-2775-45dc-9d18-b43400e51209; printf '\n'; } > ~/.ssh/personal
bw get notes 8dc6a5f7-b7bb-4556-aae0-b43400e52bf6 > ~/.ssh/personal.pub
{ bw get notes e93686a1-fb28-4bc1-ab3c-b43400e53e61; printf '\n'; } > ~/.ssh/work
bw get notes 0ce6f34e-3349-422b-9f30-b43400e547b1 > ~/.ssh/work.pub

chmod 600 ~/.ssh/personal ~/.ssh/work
chmod 644 ~/.ssh/personal.pub ~/.ssh/work.pub

# Load keys into the running ssh-agent and persist them in the macOS Keychain
# so subsequent SSH connections (including Homebrew taps via git@github.com)
# can authenticate without prompting.
ssh-add --apple-use-keychain ~/.ssh/personal ~/.ssh/work

# Write a minimal SSH config so git can use the host aliases before home-manager
# manages it. Skip if home-manager already owns the file (symlink to Nix store).
if [ -L ~/.ssh/config ]; then
  echo "  SSH config already managed by home-manager, skipping."
else
  rm -f ~/.ssh/config
  cat > ~/.ssh/config <<'SSHCONF'
Host github.com-personal
  HostName github.com
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/personal

Host github.com-work
  HostName github.com
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/work

Host *
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/infra
SSHCONF
  chmod 600 ~/.ssh/config
fi
echo "  SSH keys restored."

# --- 4. Nix ---
echo "==> Checking Nix..."
if ! command -v nix &>/dev/null; then
  echo "  Installing Nix (Determinate Systems)..."
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
    | sh -s -- install --no-confirm
  # shellcheck disable=SC1091
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
else
  echo "  Nix already installed."
fi

# --- 5. Clone home repo ---
echo "==> Cloning home config repo..."
mkdir -p ~/Projects
if [ ! -d ~/Projects/home/.git ]; then
  git clone git@github.com-personal:akunbeben/home.git ~/Projects/home
else
  echo "  ~/Projects/home already exists."
fi

# --- 5.5. Git SSH redirect ---
# /etc/gitconfig won't exist yet on first run; set the user-level config now
# so Homebrew can tap GitHub repos without credential prompts.
echo "==> Configuring git SSH redirect for GitHub..."
git config --global url."git@github.com-personal:".insteadOf "https://github.com/"

# --- 6. nix-darwin switch ---
echo "==> Running nix-darwin switch..."
# sudo drops $HOME and SSH_AUTH_SOCK; pass them explicitly so nix can fetch
# the private flake via the github.com-personal SSH host alias.
sudo \
  SSH_AUTH_SOCK="$SSH_AUTH_SOCK" \
  GIT_SSH_COMMAND="ssh -F $HOME/.ssh/config" \
  nix run nix-darwin -- switch --flake ~/Projects/home#Macbook

# --- 7. Valet ---
# laravel/homebrew-valet tap no longer exists; install via Composer instead.
# Composer bin is not in bash PATH yet; use the known path directly.
COMPOSER_BIN="$HOME/.config/composer/vendor/bin"
VALET="$COMPOSER_BIN/valet"
echo "==> Installing Laravel Valet..."
if [ -x "$VALET" ]; then
  echo "  Valet already installed, running valet install..."
  "$VALET" install
elif command -v composer &>/dev/null; then
  echo "  Installing valet via Composer..."
  composer global require laravel/valet
  "$VALET" install
else
  echo "  composer not found — install valet manually: composer global require laravel/valet"
fi

# --- 8. Android CLI ---
echo "==> Checking Android CLI..."
if ! command -v android &>/dev/null; then
  echo "  Installing Android CLI..."
  curl -fsSL https://dl.google.com/android/cli/latest/darwin_arm64/install.sh | bash
else
  echo "  Android CLI already installed."
fi

echo ""
echo "==> Done! Manual steps remaining:"
echo "  1. Log out and back in so macOS picks up the new defaults"
