{ ... }: {
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      cleanup = "uninstall";
      upgrade = true;
    };

    taps = [
      "nikitabobko/tap"
      "laravel/valet"
    ];

    brews = [
      "php"
      "laravel/valet/valet"
      "composer"
      "wireguard-tools"
    ];

    casks = [
      "kitty"
      "nikitabobko/tap/aerospace"

      "brave-browser"
      "tableplus"
      "whatsapp"
      "raycast"

      # Fonts (Kitty, Neovide)
      "karabiner-elements"

      "font-jetbrains-mono-nerd-font"
      "font-fantasque-sans-mono-nerd-font"
      # DankMono (WezTerm) is a paid font — install manually from https://dank.sh
    ];
  };
}
