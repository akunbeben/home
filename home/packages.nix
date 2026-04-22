{ pkgs, ... }: {
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
  ];
}
