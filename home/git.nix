{ inputs, ... }: {
  imports = [ (inputs.private + "/git.nix") ];

  programs.git.signing.format = "openpgp";
}
