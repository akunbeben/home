{ ... }: {
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    matchBlocks = {
      "github.com-work" = {
        hostname = "github.com";
        identityFile = "~/.ssh/work";
        extraOptions = {
          AddKeysToAgent = "yes";
          UseKeychain = "yes";
        };
      };
      "github.com-personal" = {
        hostname = "github.com";
        identityFile = "~/.ssh/personal";
        extraOptions = {
          AddKeysToAgent = "yes";
          UseKeychain = "yes";
        };
      };
      "*" = {
        identityFile = "~/.ssh/infra";
        extraOptions = {
          AddKeysToAgent = "yes";
          UseKeychain = "yes";
        };
      };
    };
  };
}
