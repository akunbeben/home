{ pkgs, inputs, ... }:
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

  # Note: next/prev tab, move tab, close/new tab to right have no ID
  # in zen-keyboard-shortcuts.json — configure those via Zen UI settings manually.
  commonShortcutsVersion = 17;
  commonShortcuts = [
    # Close tab: Alt+q
    { id = "key_close"; key = "q"; modifiers = { alt = true; control = false; shift = false; meta = false; accel = false; }; }

    # New tab: Alt+t
    { id = "key_newNavigatorTab"; key = "t"; modifiers = { alt = true; control = false; shift = false; meta = false; accel = false; }; }

    # Reload: Alt+r
    { id = "key_reload"; key = "r"; modifiers = { alt = true; control = false; shift = false; meta = false; accel = false; }; }

    # Reload clearing cache: Alt+Shift+r
    { id = "key_reload_skip_cache"; key = "r"; modifiers = { alt = true; shift = true; control = false; meta = false; accel = false; }; }

    # Focus location: Alt+l
    { id = "focusURLBar"; key = "l"; modifiers = { alt = true; control = false; shift = false; meta = false; accel = false; }; }

    # Dev tools toggle: Alt+i
    { id = "key_toggleToolbox"; key = "i"; modifiers = { alt = true; control = false; shift = false; meta = false; accel = false; }; }

    # Compact mode toggle: Alt+e
    { id = "zen-compact-mode-toggle"; key = "e"; modifiers = { alt = true; control = false; shift = false; meta = false; accel = false; }; }

    # Reopen closed tab: Alt+Shift+t
    { id = "key_restoreLastClosedTabOrWindowOrSession"; key = "t"; modifiers = { alt = true; shift = true; control = false; meta = false; accel = false; }; }

    # Download history: Cmd+Shift+j
    { id = "key_openDownloads"; key = "j"; modifiers = { accel = true; shift = true; control = false; alt = false; meta = false; }; }
    # Disable browser console (was Cmd+Shift+j)
    { id = "key_browserConsole"; disabled = true; }

    # Disable bookmark shortcuts — freed for AeroSpace (Cmd+b / Cmd+Shift+b)
    { id = "viewBookmarksSidebarKb"; disabled = true; }
    { id = "viewBookmarksToolbarKb"; disabled = true; }

    # Select tabs: Alt+1-8
    { id = "key_selectTab1"; key = "1"; modifiers = { alt = true; control = false; shift = false; meta = false; accel = false; }; }
    { id = "key_selectTab2"; key = "2"; modifiers = { alt = true; control = false; shift = false; meta = false; accel = false; }; }
    { id = "key_selectTab3"; key = "3"; modifiers = { alt = true; control = false; shift = false; meta = false; accel = false; }; }
    { id = "key_selectTab4"; key = "4"; modifiers = { alt = true; control = false; shift = false; meta = false; accel = false; }; }
    { id = "key_selectTab5"; key = "5"; modifiers = { alt = true; control = false; shift = false; meta = false; accel = false; }; }
    { id = "key_selectTab6"; key = "6"; modifiers = { alt = true; control = false; shift = false; meta = false; accel = false; }; }
    { id = "key_selectTab7"; key = "7"; modifiers = { alt = true; control = false; shift = false; meta = false; accel = false; }; }
    { id = "key_selectTab8"; key = "8"; modifiers = { alt = true; control = false; shift = false; meta = false; accel = false; }; }

    # Select last tab: Alt+9
    { id = "key_selectLastTab"; key = "9"; modifiers = { alt = true; control = false; shift = false; meta = false; accel = false; }; }
  ];
in {
  imports = [ inputs.zen-browser.homeModules.default ];

  programs.zen-browser = {
    enable = true;

    profiles."Personal" = {
      extensions.packages = commonExtensions;
      settings = commonSettings;
      keyboardShortcutsVersion = commonShortcutsVersion;
      keyboardShortcuts = commonShortcuts;
    };

    profiles."Work" = {
      extensions.packages = commonExtensions;
      settings = commonSettings;
      keyboardShortcutsVersion = commonShortcutsVersion;
      keyboardShortcuts = commonShortcuts;
    };
  };
}
