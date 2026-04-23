{ config, ... }:
let
  kittyBin = "/Applications/kitty.app/Contents/MacOS/kitty";
  syncScript = ''
    MODE=$(defaults read -g AppleInterfaceStyle 2>/dev/null)
    [ "$MODE" = "Dark" ] && THEME=macchiato || THEME=latte
    for SOCK in /tmp/kitty-*; do
      [ -S "$SOCK" ] && ${kittyBin} @ --to "unix:$SOCK" \
        set-colors --all "$HOME/.config/kitty/themes/$THEME.conf" 2>/dev/null || true
    done
  '';
in {
  imports = [
    ./packages.nix
    ./fish.nix
    ./git.nix
    ./starship.nix
    ./zen.nix
    ./repos.nix
    ./ssh.nix
  ];

  home = {
    username = "benny";
    homeDirectory = "/Users/benny";
    stateVersion = "24.11";
  };

  launchd.agents.kitty-theme-sync = {
    enable = true;
    config = {
      Label = "com.benny.kitty-theme-sync";
      ProgramArguments = [ "/bin/sh" "-c" syncScript ];
      WatchPaths = [ "${config.home.homeDirectory}/Library/Preferences/.GlobalPreferences.plist" ];
      RunAtLoad = true;
    };
  };

  home.file = {
    ".config/tmux/tmux.conf".source = ../configs/tmux.conf;
    ".config/kitty".source = ../configs/kitty;

    ".config/aerospace/aerospace.toml".source = ../configs/aerospace.toml;
    # nvim uses mkOutOfStoreSymlink so lazy-lock.json stays writable in the repo
    ".config/nvim".source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/Projects/home/configs/nvim";
    ".config/karabiner/karabiner.json".source = ../configs/karabiner.json;
    ".config/workspaces".source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/Projects/home/configs/workspaces";
  };
}
