{ pkgs, inputs, ... }:
let
  nur    = import inputs.nur { nurpkgs = pkgs; inherit pkgs; };
  addons = nur.repos.rycee.firefox-addons;
in {
  imports = [ inputs.zen-browser.homeModules.default ];

  programs.zen-browser = {
    enable = true;
    profiles."default" = {
      extensions.packages = with addons; [
        bitwarden
        darkreader
        ublock-origin
        vimium
        fake-filler
        # GoFullPage and No YouTube Shorts may not be in NUR.
        # If nix flake check fails for these, comment them out and install manually.
        # goFullPage
        # no-youtube-shorts
      ];
      settings = {
        # about:config overrides go here
        "browser.tabs.closeWindowWithLastTab" = false;
      };

      # TODO: fill in after first Zen run
      # 1. Launch Zen browser once so it creates the shortcuts file
      # 2. Find shortcut IDs:
      #    jq -c '.shortcuts[] | {id, key, keycode, action}' \
      #      ~/Library/Application\ Support/Zen/Profiles/*/zen-keyboard-shortcuts.json | fzf
      # 3. Get version: about:config → zen.keyboard.shortcuts.version
      # 4. Fill in keyboardShortcuts below
      #
      # Target shortcuts (from browser-shortcuts.md):
      #   Alt+j        → next tab
      #   Alt+k        → previous tab
      #   Alt+l        → focus location
      #   Alt+q        → close tab
      #   Alt+t        → new tab to right
      #   Alt+r        → reload
      #   Alt+i        → dev tools toggle
      #   Alt+1..9     → select tab 0..last
      #   Alt+Shift+j  → move tab next
      #   Alt+Shift+k  → move tab previous
      #   Alt+Shift+q  → close tabs to right
      #   Alt+Shift+t  → reopen closed tab
      #   Alt+Shift+r  → reload clearing cache
      keyboardShortcuts = [];
    };
  };
}
