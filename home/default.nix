{ config, lib, pkgs, ... }:
let
  kittyBin = "/Applications/kitty.app/Contents/MacOS/kitty";
  tmuxBin = "${pkgs.tmux}/bin/tmux";
  privacyMirror = pkgs.callPackage ../pkgs/privacy-mirror.nix {};
  privacyMirrorSigningIdentity = "Privacy Mirror Local Code Signing";
  terminalThemeApply = pkgs.writeShellScriptBin "terminal-theme-apply" ''
    MODE=$(defaults read -g AppleInterfaceStyle 2>/dev/null || true)
    if [ "$MODE" = "Dark" ]; then
      THEME="$HOME/.config/kitty/themes/opencode-dark.conf"
      BG="#0a0a0a"
      FG="#eeeeee"
      MUTED="#808080"
      GREEN="#7fd88f"
      BLUE="#fab283"
      CYAN="#56b6c2"
      MAGENTA="#5c9cf5"
      YELLOW="#f5a742"
    else
      THEME="$HOME/.config/kitty/themes/opencode-light.conf"
      BG="#ffffff"
      FG="#1a1a1a"
      MUTED="#8a8a8a"
      GREEN="#3d9a57"
      BLUE="#3b7dd8"
      CYAN="#318795"
      MAGENTA="#d68c27"
      YELLOW="#b0851f"
    fi

    /bin/cp "$THEME" "$HOME/.config/kitty/current-theme.conf"

    for SOCK in /tmp/kitty-*; do
      [ -S "$SOCK" ] && ${kittyBin} @ --to "unix:$SOCK" \
        set-colors --all "$THEME" 2>/dev/null || true
    done

    if ${tmuxBin} info >/dev/null 2>&1; then
      ${tmuxBin} set -g @theme_bg "$BG"
      ${tmuxBin} set -g @theme_fg "$FG"
      ${tmuxBin} set -g @theme_muted "$MUTED"
      ${tmuxBin} set -g @theme_green "$GREEN"
      ${tmuxBin} set -g @theme_blue "$BLUE"
      ${tmuxBin} set -g @theme_cyan "$CYAN"
      ${tmuxBin} set -g @theme_magenta "$MAGENTA"
      ${tmuxBin} set -g @theme_yellow "$YELLOW"
      ${tmuxBin} set -g clock-mode-colour "$BLUE"
    fi
  '';
  workHoursDisplayAwakeScript = ''
    weekday=$(/bin/date +%u)
    [ "$weekday" -le 5 ] || exit 0

    hour=$(/bin/date +%H | /usr/bin/sed 's/^0//')
    minute=$(/bin/date +%M | /usr/bin/sed 's/^0//')
    second=$(/bin/date +%S | /usr/bin/sed 's/^0//')
    now=$((hour * 3600 + minute * 60 + second))
    start=$((8 * 3600))
    end=$((17 * 3600))

    [ "$now" -ge "$start" ] && [ "$now" -lt "$end" ] || exit 0
    exec /usr/bin/caffeinate -d -t "$((end - now))"
  '';
in {
  imports = [
    ./packages.nix
    ./fish.nix
    ./git.nix
    ./starship.nix
    ./repos.nix
    ./ssh.nix
  ];

  home = {
    username = "benny";
    homeDirectory = "/Users/benny";
    stateVersion = "24.11";
  };

  manual.manpages.enable = false;

  launchd.agents.kitty-theme-sync = {
    enable = true;
    config = {
      Label = "com.benny.kitty-theme-sync";
      ProgramArguments = [ "${terminalThemeApply}/bin/terminal-theme-apply" ];
      WatchPaths = [ "${config.home.homeDirectory}/Library/Preferences/.GlobalPreferences.plist" ];
      RunAtLoad = true;
    };
  };

  launchd.agents.work-hours-display-awake = {
    enable = true;
    config = {
      Label = "com.benny.work-hours-display-awake";
      ProgramArguments = [ "/bin/sh" "-c" workHoursDisplayAwakeScript ];
      RunAtLoad = true;
      StartCalendarInterval = map (Weekday: {
        inherit Weekday;
        Hour = 8;
        Minute = 0;
      }) [ 1 2 3 4 5 ];
    };
  };

  home.activation.installPrivacyMirrorApp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    set -euo pipefail

    source_app="${privacyMirror}/share/privacy-mirror/Privacy Mirror.app"
    target_app="${config.home.homeDirectory}/Applications/Privacy Mirror.app"
    tmp_app="$target_app.tmp"
    keychain="${config.home.homeDirectory}/Library/Keychains/login.keychain-db"

    rm -rf "$tmp_app"
    mkdir -p "$(/usr/bin/dirname "$target_app")"
    cp -R "$source_app" "$tmp_app"
    chmod -R u+w "$tmp_app"

    identity=$(/usr/bin/security find-identity -v -p codesigning "$keychain" \
      | /usr/bin/awk -v name="${privacyMirrorSigningIdentity}" 'index($0, name) {print $2; exit}')

    if [ -z "$identity" ]; then
      echo "Creating ${privacyMirrorSigningIdentity} for stable Privacy Mirror Screen Recording permission..." >&2
      HOME="${config.home.homeDirectory}" ${privacyMirror}/bin/privacy-mirror-setup-signing >&2
      identity=$(/usr/bin/security find-identity -v -p codesigning "$keychain" \
        | /usr/bin/awk -v name="${privacyMirrorSigningIdentity}" 'index($0, name) {print $2; exit}')
    fi

    if [ -n "$identity" ]; then
      /usr/bin/codesign --force --deep --keychain "$keychain" --sign "$identity" "$tmp_app"
    else
      echo "error: ${privacyMirrorSigningIdentity} not found; Privacy Mirror would need Screen Recording permission again after rebuild" >&2
      exit 1
    fi

    rm -rf "$target_app"
    mv "$tmp_app" "$target_app"
  '';

  home.file = {
    ".local/bin/terminal-theme-apply".source = "${terminalThemeApply}/bin/terminal-theme-apply";
    ".pi/agent/keybindings.json".text = builtins.toJSON {
      "tui.input.newLine" = "shift+enter";
    };

    ".config/tmux/tmux.conf".source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/Projects/home/configs/tmux.conf";
    ".config/focus/sites".source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/Projects/home/configs/focus/sites";
    ".config/kitty".source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/Projects/home/configs/kitty";

    ".config/aerospace/aerospace.toml".source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/Projects/home/configs/aerospace.toml";
    # Keep the policy editable in-repo; Privacy Mirror reloads it with Cmd+R.
    ".config/privacy-mirror/config.json".source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/Projects/home/configs/privacy-mirror.json";
    # nvim uses mkOutOfStoreSymlink so lazy-lock.json stays writable in the repo
    ".config/nvim".source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/Projects/home/configs/nvim";
    "Library/Keyboard Layouts/US-NoOption.keylayout".source = ../configs/US-NoOption.keylayout;
    ".config/workspaces".source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/Projects/home-private/workspaces";
  };
}
