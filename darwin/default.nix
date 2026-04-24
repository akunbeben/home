{ pkgs, inputs, ... }: {
  imports = [
    ./homebrew.nix
    ./system.nix
  ];

  users.users.benny = {
    name = "benny";
    home = "/Users/benny";
    shell = pkgs.fish;
  };

  programs.fish.enable = true;
  environment.shells = [ pkgs.fish ];

  system.activationScripts.postActivation.text = ''
    fish=/run/current-system/sw/bin/fish
    current=$(dscl . -read /Users/benny UserShell | awk '{print $2}')
    if [ "$current" != "$fish" ]; then
      chsh -s "$fish" benny
    fi
  '';

  # System-level SSH host aliases so root/sudo can resolve github.com-personal
  # during nix evaluation (e.g. darwin-rebuild switch fetching the private flake).
  environment.etc."ssh/ssh_config.d/github-aliases.conf".text = ''
    Host github.com-personal
      HostName github.com
      User git
      IdentityFile /Users/benny/.ssh/personal
      IdentitiesOnly yes

    Host github.com-work
      HostName github.com
      User git
      IdentityFile /Users/benny/.ssh/work
      IdentitiesOnly yes
  '';

  nixpkgs.config.allowUnfree = true;

  # Determinate Nix manages its own daemon; hand off Nix management entirely.
  # nix.settings and nix.gc are unavailable when nix.enable = false.
  # Determinate enables nix-command and flakes by default, and handles GC
  # via its own tooling (nix gc / determinate-nixd).
  nix.enable = false;

  system.primaryUser = "benny";
  nixpkgs.hostPlatform = "aarch64-darwin";
  system.stateVersion = 5;
}
