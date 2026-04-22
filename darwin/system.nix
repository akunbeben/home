{ ... }: {
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
      KeyRepeat = 2;
      InitialKeyRepeat = 15;
      # Disable press-and-hold so key repeat works in neovim
      ApplePressAndHoldEnabled = false;
    };
  };
}
