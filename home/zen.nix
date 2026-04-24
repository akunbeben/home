{ pkgs, lib, inputs, ... }:
let
  nur    = import inputs.nur { nurpkgs = pkgs; inherit pkgs; };
  addons = nur.repos.rycee.firefox-addons;

  commonExtensions = with addons; [
    bitwarden
    darkreader
    ublock-origin
    vimium
    fake-filler
  ];

  commonSettings = {
    "browser.tabs.closeWindowWithLastTab" = false;
    "zen.tabs.vertical.right-side" = true;
  };

  commonShortcutsVersion = 17;
  commonShortcuts = [
    { id = "key_close";                                  key = "q"; modifiers = { alt = true;  control = false; shift = false; meta = false; accel = false; }; }
    { id = "key_newNavigatorTab";                        key = "t"; modifiers = { alt = true;  control = false; shift = false; meta = false; accel = false; }; }
    { id = "key_reload";                                 key = "r"; modifiers = { alt = true;  control = false; shift = false; meta = false; accel = false; }; }
    { id = "key_reload_skip_cache";                      key = "r"; modifiers = { alt = true;  control = false; shift = true;  meta = false; accel = false; }; }
    { id = "focusURLBar";                                key = "l"; modifiers = { alt = true;  control = false; shift = false; meta = false; accel = false; }; }
    { id = "key_toggleToolbox";                          key = "i"; modifiers = { alt = true;  control = false; shift = false; meta = false; accel = false; }; }
    { id = "zen-compact-mode-show-sidebar";              key = "e"; modifiers = { alt = true;  control = false; shift = false; meta = false; accel = false; }; }
    { id = "zen-compact-mode-toggle";                    key = "e"; modifiers = { alt = true;  shift = true;  control = false; meta = false; accel = false; }; }
    { id = "key_restoreLastClosedTabOrWindowOrSession";  key = "t"; modifiers = { alt = true;  control = false; shift = true;  meta = false; accel = false; }; }
    { id = "key_openDownloads";                          key = "j"; modifiers = { accel = true; shift = true;  control = false; alt = false; meta = false; }; }
    { id = "key_browserConsole";    disabled = true; }
    { id = "viewBookmarksSidebarKb"; disabled = true; }
    { id = "viewBookmarksToolbarKb"; disabled = true; }
    { id = "key_selectTab1"; key = "1"; modifiers = { alt = true; control = false; shift = false; meta = false; accel = false; }; }
    { id = "key_selectTab2"; key = "2"; modifiers = { alt = true; control = false; shift = false; meta = false; accel = false; }; }
    { id = "key_selectTab3"; key = "3"; modifiers = { alt = true; control = false; shift = false; meta = false; accel = false; }; }
    { id = "key_selectTab4"; key = "4"; modifiers = { alt = true; control = false; shift = false; meta = false; accel = false; }; }
    { id = "key_selectTab5"; key = "5"; modifiers = { alt = true; control = false; shift = false; meta = false; accel = false; }; }
    { id = "key_selectTab6"; key = "6"; modifiers = { alt = true; control = false; shift = false; meta = false; accel = false; }; }
    { id = "key_selectTab7"; key = "7"; modifiers = { alt = true; control = false; shift = false; meta = false; accel = false; }; }
    { id = "key_selectTab8"; key = "8"; modifiers = { alt = true; control = false; shift = false; meta = false; accel = false; }; }
    { id = "key_selectLastTab"; key = "9"; modifiers = { alt = true; control = false; shift = false; meta = false; accel = false; }; }
    { id = "zen-split-view-vertical"; key = "v"; modifiers = { alt = true; control = false; shift = false; meta = false; accel = false; }; }
  ];
in {
  imports = [ inputs.zen-browser.homeModules.default ];

  programs.zen-browser = {
    enable = true;
    policies = {
      DisableAppUpdate = true;
      DisableTelemetry = true;
    };

    profiles."Personal" = {
      id = 0;
      isDefault = true;
      extensions.packages = commonExtensions;
      settings = commonSettings;
      keyboardShortcutsVersion = commonShortcutsVersion;
      keyboardShortcuts = commonShortcuts;
    };

    profiles."Work" = {
      id = 1;
      isDefault = false;
      extensions.packages = commonExtensions;
      settings = commonSettings;
      keyboardShortcutsVersion = commonShortcutsVersion;
      keyboardShortcuts = commonShortcuts;
    };
  };

  # profiles.ini is a read-only nix symlink — Zen cannot write to it, so the
  # profile chooser fails with "changes could not be saved". Pre-creating
  # installs.ini with the stable install ID (derived from the symlink path
  # ~/Applications/Zen Browser (Beta).app) bypasses the chooser entirely so
  # Zen never needs to touch profiles.ini.
  home.activation.zenInstallsIni = lib.hm.dag.entryAfter ["writeBoundary"] ''
    _ZEN="$HOME/Library/Application Support/Zen"
    _INI="$_ZEN/installs.ini"
    if [ ! -f "$_INI" ]; then
      mkdir -p "$_ZEN"
      printf '[D77C755FAA976AAE]\nDefault=Profiles/Personal\nLocked=1\n' > "$_INI"
    fi
  '';
}
