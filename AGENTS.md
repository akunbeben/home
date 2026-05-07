# Repository Guidelines

## Project Structure & Module Organization

This repository is a nix-darwin plus Home Manager configuration for the `Macbook` host.

- `flake.nix` defines inputs and the `darwinConfigurations.Macbook` entry point.
- `darwin/` contains system-level macOS, Homebrew, and shell setup.
- `home/` contains Home Manager modules for packages, Fish, Git, SSH, Zen Browser, and repo activation.
- `pkgs/` contains custom Nix packages and scripts (`ssht`, `work`, `boc`).
- `configs/` contains raw dotfiles symlinked into the user environment, including Neovim, Kitty, tmux, Aerospace, and Karabiner.
- `scripts/` contains operational helpers for bootstrap and project scanning.

Private Git identity and repo lists are imported through the private flake input, not stored here.

## Build, Test, and Development Commands

- `sudo SSH_AUTH_SOCK="$SSH_AUTH_SOCK" GIT_SSH_COMMAND="ssh -F $HOME/.ssh/config" darwin-rebuild switch --flake ~/Projects/home#Macbook` applies system and Home Manager changes.
- `nix flake check` evaluates the flake and catches syntax or module errors.
- `bash scripts/bootstrap.sh` bootstraps a fresh macOS machine; run it once, not during normal development.
- `bash scripts/scan-projects.sh` scans `~/Projects` and prints Nix-formatted repo entries for review.

There is no separate test suite. Treat successful flake evaluation and rebuild as validation.

## Coding Style & Naming Conventions

Use two-space indentation in Nix files and keep modules focused by domain (`home/fish.nix`, `darwin/homebrew.nix`). Prefer existing patterns over new abstractions. Use lowercase, descriptive filenames.

Shell scripts should use Bash, include `set -euo pipefail` where practical, quote variables, and keep output short. Dotfiles under `configs/` should preserve each tool’s native style.

## Testing Guidelines

Before submitting Nix changes, run `nix flake check` when possible. For changes affecting activation, packages, services, or symlinks, run the full `darwin-rebuild switch` command. For script changes, run the script directly with a harmless target, for example `bash scripts/scan-projects.sh ~/Projects`.

## Commit & Pull Request Guidelines

Recent history uses short Conventional Commit-style subjects, mainly `feat:` and `chore:`. Use imperative, scoped summaries such as `feat: add docker` or `chore: update keyboard layout`.

Pull requests should describe what changed, note whether `nix flake check` or `darwin-rebuild switch` was run, and call out any manual follow-up such as app login, Keychain access, browser configuration, or private flake updates.

## Security & Configuration Tips

Do not commit secrets, private keys, machine-local tokens, or private repo metadata. Keep SSH host aliases aligned with `home/ssh.nix`: `github.com-personal`, `github.com-work`, and the default infra identity.
