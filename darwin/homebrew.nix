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
      "raycast"

      # Fonts (Kitty, Neovide)
      "karabiner-elements"

      "font-jetbrains-mono-nerd-font"
      "font-fantasque-sans-mono-nerd-font"
      # DankMono (WezTerm) is a paid font — install manually from https://dank.sh
    ];
  };
}
