{
  description = "A very basic flake";

  inputs.utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, utils }: 

  utils.lib.eachSystem (utils.lib.defaultSystems) ( system:
  let
    pkgs = nixpkgs.legacyPackages."${system}";
  in
  {

  }) // {
    nixosModules.ep3-bs = import ./ep3-bs.nix;

    nixosConfigurations.test = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";

      modules = [
        ./ep3-bs.nix
        {
          services.ep3-bs.enable = true;
          services.ep3-bs.mail.address = "test@test.de";
          services.ep3-bs.database.user = "testuser3";
          services.ep3-bs.database.password = "testPassword1234";
          users.users.test = {
            isNormalUser = true;
            extraGroups = [ "wheel" ];
            initialPassword = "test";
          };

          virtualisation.vmVariant.virtualisation.graphics = true;
        }
      ];
    };

    packages.x86_64-linux.testVM = self.nixosConfigurations.test.config.system.build.vm;
  };
}
