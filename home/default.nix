{ config, lib, pkgs, ... }:
let
  kittyBin = "/Applications/kitty.app/Contents/MacOS/kitty";
  privacyMirror = pkgs.callPackage ../pkgs/privacy-mirror.nix {};
  privacyMirrorSigningIdentity = "Privacy Mirror Local Code Signing";
  syncScript = ''
    MODE=$(defaults read -g AppleInterfaceStyle 2>/dev/null)
    [ "$MODE" = "Dark" ] \
      && THEME="$HOME/.config/kitty/kitty-themes/themes/Dracula.conf" \
      || THEME="$HOME/.config/kitty/themes/latte.conf"
    for SOCK in /tmp/kitty-*; do
      [ -S "$SOCK" ] && ${kittyBin} @ --to "unix:$SOCK" \
        set-colors --all "$THEME" 2>/dev/null || true
    done
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
      ProgramArguments = [ "/bin/sh" "-c" syncScript ];
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

    if [ -n "$identity" ]; then
      /usr/bin/codesign --force --deep --keychain "$keychain" --sign "$identity" "$tmp_app"
    else
      echo "warning: ${privacyMirrorSigningIdentity} not found; run privacy-mirror-setup-signing once for stable Screen Recording permission" >&2
      /usr/bin/codesign --force --deep --sign - "$tmp_app"
    fi

    rm -rf "$target_app"
    mv "$tmp_app" "$target_app"
  '';

  home.file = {
    ".config/tmux/tmux.conf".source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/Projects/home/configs/tmux.conf";
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
    ".config/karabiner/karabiner.json".source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/Projects/home/configs/karabiner.json";
    "Library/Keyboard Layouts/US-NoOption.keylayout".source = ../configs/US-NoOption.keylayout;
    ".config/workspaces".source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/Projects/home-private/workspaces";
  };
}
