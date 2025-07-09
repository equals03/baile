{
  lib,
  flake-parts-lib,
  moduleLocation,
  ...
}: let
  inherit (builtins) mapAttrs;
  inherit (lib) types;
in {
  options = {
    flake = flake-parts-lib.mkSubmoduleOptions {
      baileConfigurations = lib.mkOption {
        type = types.lazyAttrsOf types.raw;
        default = {};
        description = ''
          Instantiated baile configurations.

          `baileConfigurations` is for specific installations. If you want to expose
          reusable configurations, add them to `baileModules` in the form of modules, so
          that you can reference them in this or another flake's `baileConfigurations`.
        '';
      };
      baileModules = lib.mkOption {
        type = types.lazyAttrsOf types.deferredModule;
        default = {};
        apply = mapAttrs (
          k: v: {
            _class = "baile";
            _file = "${toString moduleLocation}#baileModules.${k}";
            imports = [v];
          }
        );
        description = ''
          baile modules.

          You may use this for reusable pieces of configuration, service modules, etc.
        '';
      };
    };
  };
}
