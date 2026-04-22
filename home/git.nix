{ inputs, ... }: {
  imports = [ (inputs.private + "/git.nix") ];
}
