# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A nix-darwin + home-manager configuration for a single macOS machine (`aarch64-darwin`, hostname `Macbook`). Everything declarative lives here; secrets and private git config live in the separate private flake input.

## Applying changes

```bash
# Apply the full config (system + home-manager)
sudo darwin-rebuild switch --flake ~/Projects/home#Macbook

# Bootstrap a brand-new machine (run once)
bash ~/Projects/home/scripts/bootstrap.sh
```

There are no tests or lint commands — changes are validated by a successful `darwin-rebuild switch`.

## Flake inputs

| Input | Purpose |
|---|---|
| `nixpkgs` | Tracks `nixpkgs-unstable` |
| `nix-darwin` | macOS system configuration |
| `home-manager` | User environment |
| `NUR` | Firefox/Zen browser add-ons |
| `zen-browser` | Zen browser flake + home module |
| `private` | SSH-cloned private flake (`akunbeben/home-private`) — contains git identity config and the repo clone list |

## Directory layout

```
darwin/         system-level (homebrew, macOS defaults, shell)
home/           home-manager modules
  packages.nix  all Nix-managed packages
  fish.nix      shell aliases, abbreviations, functions, path
  zen.nix       Zen browser profiles + extensions + shortcuts
  repos.nix     auto-clone personal/work repos on first activation
  ssh.nix       SSH match blocks (github.com-personal, github.com-work, *)
  git.nix       delegates to private flake
pkgs/           custom derivations
  ssht.nix      Go CLI fetched from GitHub (akunbeben/ssht)
  work.nix      shell script: tmux session launcher per project
  boc.nix       shell script: BOC multi-repo git-status table + tmux session
configs/        raw dotfiles symlinked by home-manager
  nvim/         Neovim config (mkOutOfStoreSymlink — stays writable)
  workspaces/   per-project tmux layouts (mkOutOfStoreSymlink — stays writable)
  tmux.conf, kitty/, aerospace.toml, karabiner.json
scripts/
  bootstrap.sh      first-time machine setup
  scan-projects.sh  scan ~/Projects for git repos → prints nix clone list
```

## Package managers split

- **Nix** manages: CLI tools (eza, bat, fd, ripgrep, fzf, jq, lazygit, lazydocker, lazysql, yazi), runtimes (fnm, bun, go, rustc/cargo), editors (neovim, tmux), and the custom pkgs above.
- **Homebrew** manages: GUI casks (kitty, aerospace, tableplus, karabiner-elements, raycast, fonts) and the PHP/Valet/Composer stack.

## Key architectural details

**Private flake**: `git+ssh://git@github.com-personal/akunbeben/home-private` is a non-flake input. `home/git.nix` and `home/repos.nix` import from it at eval time. Changes to git identity or the repo clone list go there.

**Writable symlinks**: `configs/nvim` and `configs/workspaces` use `mkOutOfStoreSymlink` so `lazy-lock.json` and workspace `.conf` files can be edited in place without a rebuild.

**SSH identities**: Two GitHub host aliases are configured — `github.com-personal` (uses `~/.ssh/personal`) and `github.com-work` (uses `~/.ssh/work`). All other hosts use `~/.ssh/infra`. Clone URLs must use these aliases to pick the right key.

**Zen browser profiles**: Each profile requires a unique integer `id` and exactly one must have `isDefault = true`. Tab shortcuts (next/prev, move, close/new-to-right) have no id in zen-keyboard-shortcuts.json and must be configured manually in the Zen UI.

**Updating ssht hash**: When bumping the `ssht` Go package to a new commit, run `nix-prefetch-github akunbeben ssht --rev main` and paste the result into `pkgs/ssht.nix`.

**`work` CLI**: Reads `~/.config/workspaces/<project>.conf` (sourced on top of `default.conf`) to define up to 4 tmux windows with commands. Use `work edit <project>` to create/edit a conf, `work <project>` or `work .` to open the session.

**`boc` CLI**: `boc gst` shows a git-status table across all BOC repos; `boc work` opens a tmux session with each repo in nvim + an eops window running Claude Code.

**Fish environment**: `~/.env` is loaded automatically via `envsource` on every shell start. Node version switching is handled by `fnm --use-on-cd`.
