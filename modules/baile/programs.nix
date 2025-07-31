{
  pkgs,
  config,
  options,
  lib,
  ...
}: let
  inherit (builtins) map mapAttrs;
  inherit (lib) baile types;

  cfg = config.programs;

  programs' = baile.only-enabled cfg;

  override-package = baile.overloaded {
    derivation = package: (
      baile.overloaded {
        lambda = package.overrideAttrs;
        set = package.override;
        null = _: package;
      }
    );
    null = _: lib.id;
  };

  get-program-package = baile.overloaded {
    list = programs: lib.flatten (map get-program-package programs);
    string = program: cfg.${program}.package or pkgs.${program};
    default = lib.id;
  };

  mkXdgFilesOption = relative-to:
    lib.mkOption {
      type = with types; attrsOf (baile.types.file.coerced.relative-to relative-to);
      default = {};
      description = "Files to install for this user relative to ~/${relative-to}";
    };

  program-type = types.submodule ({
    name,
    config,
    ...
  }: {
    imports = [
    ];
    options = {
      enable =
        lib.mkEnableOption "${config.name}";

      package =
        lib.mkPackageOption pkgs name {
          nullable = true;
        }
        // {
          apply = lib.flip override-package config.override;
        };

      extraPackages = lib.mkOption {
        type = with types; oneOf [str package (listOf (either package str))];
        default = [];
        apply = baile.compose-all [
          lib.toList
          (map get-program-package)
          lib.flatten
        ];
      };

      override = lib.mkOption {
        type = with types; uniq (nullOr (either (lazyAttrsOf unspecified) baile.types.function));
        default = null;
      };

      config = lib.mkOption {
        type = baile.mkDeferredModuleType ({program, ...}: {
          _file = ./programs.nix;
          config = {
            packages = (lib.optionals (program.package != null) [program.package]) ++ program.extraPackages;
          };
        });
        default = {};
        apply = module:
          (lib.evalModules {
            modules = [
              module
              {
                options = {
                  inherit (options) assertions;
                  inherit (options) warnings;
                  environment.activation = options.environment.activation;
                  inherit (options) files;
                  inherit (options) packages;

                  xdg = mapAttrs (_name: value: {files = mkXdgFilesOption value.path;}) options.xdg.value;
                };
              }
            ];

            prefix = ["programs" name];
            specialArgs = {program = config;};
            class = "baileProgram";
          }).config;
      };
    };
  });
in {
  options = {
    programs = lib.mkOption {
      type = with types; attrsOf program-type;
      default = {};
    };
  };

  config = let
    normalise = lib.mapAttrsToList (_: file: {${file.target} = file;});
    program-files = lib.concatLists [
      (lib.mapAttrsToList
        (_: program:
          lib.mkMerge (lib.concatLists [
            (normalise program.config.files or {})
            (lib.flatten (lib.mapAttrsToList (_: c: normalise c.files) program.config.xdg))
          ]))
        programs')
    ];

    program-packages = lib.concatLists [
      (lib.mapAttrsToList (_: program: program.config.packages or {}) programs')
    ];

    program-environments = lib.concatLists [
      (lib.mapAttrsToList (_: program: program.config.environment or {}) programs')
    ];
  in {
    _module.args = {
      inherit programs' get-program-package;
    };

    assertions =
      lib.concatLists
      (lib.mapAttrsToList (name: program:
        map ({
          assertion,
          message,
          ...
        }: {
          inherit assertion;
          message = "${name}: ${message}";
        })
        program.config.assertions)
      programs');

    warnings =
      lib.concatLists
      (lib.mapAttrsToList (
          name: program:
            map (warning: "${name}: ${warning}")
            program.config.warnings
        )
        programs');

    files = lib.mkMerge program-files;
    packages = lib.mkMerge program-packages;
    environment = lib.mkMerge program-environments;
  };
}
