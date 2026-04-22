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
    ];

    casks = [
      "ghostty"
      "kitty"
      "wezterm"
      "nikitabobko/tap/aerospace"
      "neovide"
      "brave-browser"
      "tableplus"
      "whatsapp"

      # Fonts (Kitty, Neovide)
      "karabiner-elements"

      "font-jetbrains-mono-nerd-font"
      "font-fantasque-sans-mono-nerd-font"
      # DankMono (WezTerm) is a paid font — install manually from https://dank.sh
    ];
  };
}
