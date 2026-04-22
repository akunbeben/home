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
    };
  };
}
