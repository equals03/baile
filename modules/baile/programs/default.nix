{
  pkgs,
  config,
  options,
  lib,
  ...
}: let
  inherit (builtins) map mapAttrs attrValues;
  inherit (lib) baile types;

  cfg = config.programs;

  get-program-package = baile.overloaded {
    list = programs: lib.flatten (map get-program-package programs);
    string = program: let
      pkg = cfg.${program}.package or null;
      path = lib.splitString "." program;
    in
      if pkg != null
      then pkg
      else (lib.attrByPath path null pkgs);
    default = lib.id;
  };

  program-type = baile.mkDeferredModuleType ({
    name,
    config,
    ...
  }: {
    _file = ./default.nix;
    imports = [./packages.nix];
    options = {
      enable = lib.mkEnableOption name;
      description = lib.mkOption {
        type = types.str;
        default = config.package.meta.description or "";
      };

      inherit (options) files;
      environment = {inherit (options.environment) activation sessionVariables;};
      systemd = {inherit (options.systemd) sessionVariables;};
      xdg.dirs = lib.mkOption {
        type = types.attrsOf (types.submodule {options = {inherit (options) files;};});
        default = {};
      };
    };
    config = {
      _module.args = {
        inherit get-program-package;
      };
    };
  });
in {
  options = {
    programs = lib.mkOption {
      type = with types; attrsOf program-type;
      default = {};
      apply = lib.mapAttrs (
        name: mod:
          (lib.evalModules {
            modules = [
              mod
            ];
            specialArgs = {
              inherit name pkgs lib;
              baile-cfg = config;
            };
            prefix = ["programs" name];
            class = "baileProgram";
          }).config
      );
    };
  };

  config = let
    programs' = baile.only-enabled cfg;
    program-configurations = attrValues (mapAttrs (_: conf: {
        inherit (conf) environment files xdg;
        packages = (lib.optionals (conf.package != null) [conf.package]) ++ conf.extraPackages;
      })
      programs');

    extract-cfg = name: lib.mkMerge (map (c: c."${name}") program-configurations);
  in {
    _module.args = {
      inherit get-program-package;
    };

    packages = extract-cfg "packages";
    files = extract-cfg "files";
    environment = extract-cfg "environment";
    xdg = extract-cfg "xdg";
  };
}
