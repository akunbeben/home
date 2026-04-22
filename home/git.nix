{ ... }: {
  programs.git = {
    enable = true;
    userName  = "Benny Rahmat";
    userEmail = "akunbeben@gmail.com";
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = false;
      core.editor = "nvim";
    };
  };
}
