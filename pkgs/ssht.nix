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
    hash  = "sha256-3Szng7fEqc+nyEMEMWaBxnvJfqecoRAuIqhTzTwCASE=";
  };

  vendorHash = "sha256-TVKmcJadu+VNi5nsKC/j9Gwh9WWbFoR9NCgmYUpkx7o=";
}
