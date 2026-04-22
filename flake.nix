{
  description = "Benny's home configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nur.url = "github:nix-community/NUR";
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    private = {
      url = "git+ssh://git@github.com-personal/akunbeben/home-private";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, nix-darwin, home-manager, nur, zen-browser, ... }@inputs: {
    darwinConfigurations.Macbook = nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      specialArgs = { inherit inputs; };
      modules = [
        ./darwin
        home-manager.darwinModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            users.benny = import ./home;
            extraSpecialArgs = { inherit inputs; };
          };
        }
      ];
    };
  };
}
