{ ... }: {
  # Redirect GitHub HTTPS to the personal SSH alias so Homebrew can tap
  # public repos without credential prompts. Brew runs as the user but
  # reads /etc/gitconfig before home-manager has applied ~/.gitconfig.
  environment.etc."gitconfig".text = ''
    [url "git@github.com-personal:"]
      insteadOf = https://github.com/
  '';

  system.defaults = {
    dock = {
      autohide = true;
      show-recents = false;
    };
    finder = {
      AppleShowAllExtensions = true;
      ShowPathbar = true;
    };
    NSGlobalDomain = {
      KeyRepeat = 1;
      InitialKeyRepeat = 15;
      # Disable press-and-hold so key repeat works in neovim
      ApplePressAndHoldEnabled = false;
    };
  };
}
