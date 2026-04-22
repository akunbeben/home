{ config, ... }: {
  imports = [
    ./packages.nix
    ./fish.nix
    ./git.nix
    ./starship.nix
  ];

  home = {
    username = "benny";
    homeDirectory = "/Users/benny";
    stateVersion = "24.11";
  };

  home.file = {
    ".config/tmux/tmux.conf".source = ../configs/tmux.conf;
    ".config/kitty".source = ../configs/kitty;

    ".config/aerospace.toml".source = ../configs/aerospace.toml;
    # nvim uses mkOutOfStoreSymlink so lazy-lock.json stays writable in the repo
    ".config/nvim".source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/Projects/home/configs/nvim";
    ".config/karabiner/karabiner.json".source = ../configs/karabiner.json;
  };
}
