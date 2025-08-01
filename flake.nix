{
  description = "There's no place like baile.";

  outputs = {
    self,
    nixpkgs,
    ...
  }: let
    forAllSystems = nixpkgs.lib.genAttrs ["x86_64-linux"];
  in {
    lib = import ./lib;

    # depreciated, use `nixosModules` instead
    nixosModule = self.nixosModules.baile;
    nixosModules = {
      baile = rec {
        _file = ./modules/nixos;
        imports = [_file];
      };
      default = self.nixosModules.baile;
    };

    flakeModule = self.flakeModules.baile;
    flakeModules = {
      baile = rec {
        _file = ./modules/flake-module;
        _class = "flake";
        imports = [_file];
      };
      default = self.flakeModules.baile;
    };

    baileModules = {
      extra = rec {
        _file = ./modules/baile-extra;
        _class = "baile";
        imports = [_file];
      };
    };

    checks = forAllSystems (
      system: let
        pkgs = import nixpkgs {inherit system;};

        run-test = test:
          pkgs.testers.runNixOSTest {
            imports = [
              test
            ];
            defaults = {
              imports = [
                ./tests/lib
                self.nixosModules.baile
                {config._module.args = {inherit self;};}
              ];
              documentation.enable = false;
              networking.firewall.enable = false;
            };
          };
      in {
        baile-packages = run-test ./tests/packages.nix;
        baile-programs = run-test ./tests/programs.nix;
        baile-files = run-test ./tests/files.nix;
      }
    );
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-unstable";
  };
}
