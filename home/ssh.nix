{ ... }: {
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    settings = {
      "github.com-work" = {
        HostName = "github.com";
        IdentityFile = "~/.ssh/work";
        IdentitiesOnly = true;
        AddKeysToAgent = "yes";
        UseKeychain = "yes";
      };
      "github.com-personal" = {
        HostName = "github.com";
        IdentityFile = "~/.ssh/personal";
        IdentitiesOnly = true;
        AddKeysToAgent = "yes";
        UseKeychain = "yes";
      };
      "*" = {
        IdentityFile = "~/.ssh/infra";
        IdentitiesOnly = true;
        AddKeysToAgent = "yes";
        UseKeychain = "yes";
      };
    };
  };
}
