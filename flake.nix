{
  description = "A very basic flake";

  inputs.utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, utils }: 

  utils.lib.eachSystem (utils.lib.defaultSystems) ( system:
  let
    pkgs = nixpkgs.legacyPackages."${system}";
  in
  {
    devShells.default = pkgs.mkShell {
      shellHook = ''
        export QEMU_NET_OPTS="hostfwd=tcp::2221-:22,hostfwd=tcp::8080-:80"
      '';
    };

    packages.ep3-bs = with pkgs; stdenv.mkDerivation {
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

  }) // {

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
