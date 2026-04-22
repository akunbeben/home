{ pkgs }:
pkgs.buildGoModule {
  pname = "ssht";
  version = "unstable";

  src = pkgs.fetchFromGitHub {
    owner = "akunbeben";
    repo  = "ssht";
    rev   = "main";
    # Run: nix-prefetch-github akunbeben ssht --rev main
    # then paste the hash here
    hash  = pkgs.lib.fakeHash;
  };

  # Set to null first; if build fails with "cannot find module", set to pkgs.lib.fakeHash
  # and replace with the hash from the error message
  vendorHash = null;
}
