{ ... }: {
  programs.git = {
    enable = true;
    settings = {
      user.name  = "Benny Rahmat";
      user.email = "akunbeben@gmail.com";
      init.defaultBranch = "main";
      pull.rebase = false;
      core.editor = "nvim";
    };
    includes = [
      {
        condition = "gitdir:~/Work/";
        contents.user.email = "benny.rahmat@thrive.co.id";
      }
    ];
  };
}
