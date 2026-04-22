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
    ];
  };
}
