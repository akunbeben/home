{ pkgs, inputs, ... }: {
  imports = [
    ./homebrew.nix
    ./system.nix
  ];

  users.users.benny = {
    name = "benny";
    home = "/Users/benny";
  };

  programs.fish.enable = true;
  environment.shells = [ pkgs.fish ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.gc = {
    automatic = true;
    interval = { Weekday = 0; Hour = 2; Minute = 0; };
    options = "--delete-older-than 30d";
  };

  system.primaryUser = "benny";
  nixpkgs.hostPlatform = "aarch64-darwin";
  system.stateVersion = 5;
}
