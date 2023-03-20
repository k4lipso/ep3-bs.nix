{
  description = "A very basic flake";

  outputs = { self, nixpkgs }: 
  {

    packages.x86_64-linux.ep3-bs =
      with import nixpkgs { system = "x86_64-linux"; };
      stdenv.mkDerivation {
        name = "ep3-bs";
      
        src = fetchFromGitHub {
          owner = "tkrebs";
          repo = "ep3-bs";
          rev = "1.8.1";
          sha256 = "sha256-mcuFgi1ebawaAyuEREsC9jdIqGA0BeMabqwiVcXsKSY=";
        };

        installPhase = ''
          runHook preInstall
          mkdir -p $out/
          cp -R . $out/
          runHook postInstall
        '';

      };

    nixosModules.ep3-bs = import ./ep3-bs.nix;

    nixosConfigurations.test = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";

      modules = [
        ./ep3-bs.nix
        {
          services.ep3-bs.enable = true;
          services.ep3-bs.database.user = "testuser3";
          services.ep3-bs.database.password = "testPassword1234";
          users.users.test = {
            isNormalUser = true;
            extraGroups = [ "wheel" ];
            initialPassword = "test";
          };
        }
      ];
    };
    #packages.x86_64-linux.default = self.packages.x86_64-linux.hello;

  };
}
