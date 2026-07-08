{ config, lib, pkgs, ... }: {
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      cleanup = "uninstall";
      extraFlags = [ "--force-cleanup" ];
      upgrade = true;
    };

    taps = [
      "homebrew/cask"
      "nikitabobko/tap"
      "vicentereig/tap"
    ];

    brews = [
      "php"
      "composer"
      "dnsmasq"
      "nginx"
      "openjdk@21"
      "wireguard-tools"
      "bitwarden-cli"
      "rtk"
      "whatsapp-cli"
      "sherlock"
    ];

    casks = [
      "kitty"
      "nikitabobko/tap/aerospace"


      "tableplus"
      "dbngin"
      {
        name = "brave-browser";
        greedy = true;
        postinstall = ''
          /usr/bin/xattr -dr com.apple.FinderInfo '/Applications/Brave Browser.app'
        '';
      }
      "google-chrome"
      "whatsapp"
      "telegram"
      "raycast"

      "karabiner-elements"
      "codex"

      "font-jetbrains-mono-nerd-font"
      "font-fantasque-sans-mono-nerd-font"
      "font-sf-mono-nerd-font-ligaturized"
    ];
  };

  system.activationScripts.homebrew.text = lib.mkForce ''
    # Homebrew Bundle
    echo >&2 "Homebrew bundle..."
    if [ -f "${config.homebrew.prefix}/bin/brew" ]; then
      PATH="${config.homebrew.prefix}/bin:${lib.makeBinPath [ pkgs.mas ]}:$PATH" \
      sudo \
        --preserve-env=PATH \
        --user=${lib.escapeShellArg config.homebrew.user} \
        --set-home \
        env \
        HOMEBREW_NO_INSTALL_FROM_API=1 \
        brew tap --force homebrew/cask
      PATH="${config.homebrew.prefix}/bin:${lib.makeBinPath [ pkgs.mas ]}:$PATH" \
      sudo \
        --preserve-env=PATH \
        --user=${lib.escapeShellArg config.homebrew.user} \
        --set-home \
        env \
        HOMEBREW_NO_INSTALL_FROM_API=1 \
        ${config.homebrew.onActivation.brewBundleCmd}
    else
      echo -e "\e[1;31merror: Homebrew is not installed, skipping...\e[0m" >&2
    fi
  '';
}
