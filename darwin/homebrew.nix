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
    ];

    brews = [
      "php"
      "composer"
      "dnsmasq"
      "nginx"
      "wireguard-tools"
      "bitwarden-cli"
      "rtk"
    ];

    casks = [
      "kitty"
      "nikitabobko/tap/aerospace"


      "tableplus"
      "whatsapp"
      "telegram"
      "raycast"

      "karabiner-elements"

      "font-jetbrains-mono-nerd-font"
      "font-fantasque-sans-mono-nerd-font"
    ];
  };
}
