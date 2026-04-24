{ pkgs, inputs, ... }:
let
  ssht  = import ../pkgs/ssht.nix { inherit pkgs; };
  work  = import ../pkgs/work.nix { inherit pkgs; };
  boc   = import ../pkgs/boc.nix  { inherit pkgs; };
  gws = inputs.googleworkspace-cli.packages.${pkgs.system}.default;
in {
  home.packages = with pkgs; [
    # Shell
    fish
    starship

    # File tools
    eza
    yazi
    fd
    ripgrep
    bat
    fzf

    # Dev utilities
    jq
    wget
    curl
    htop
    git

    # TUI tools
    lazygit
    lazydocker
    lazysql

    # Editors & multiplexers
    neovim
    tmux

    # Runtimes
    fnm
    bun

    # Go
    go

    # Rust (nix-managed, not rustup)
    rustc
    cargo
    rustfmt
    clippy
    rust-analyzer

    # Cloud & release tools
    cloudflared
    goreleaser
    google-cloud-sdk

    # Claude Code CLI
    claude-code

    # Custom
    ssht
    work
    boc
    gws
  ];
}
