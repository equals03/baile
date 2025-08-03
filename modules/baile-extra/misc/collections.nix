{
  lib,
  config,
  options,
  ...
}: let
  inherit (builtins) map mapAttrs attrValues;
  inherit (lib) baile types;

  cfg = config.collections;
in {
  options = {
    collections = lib.mkOption {
      type = with types;
        attrsOf (submodule ({name, ...}: {
          options = {
            enable = lib.mkEnableOption "collection";
            description = lib.mkOption {
              type = nullOr str;
              default = "a collection of ${name}";
            };

            inherit (options) programs files;
            environment = {inherit (options.environment) activation sessionVariables;};
            xdg.dirs = lib.mkOption {
              type = types.attrsOf (types.submodule {options = {inherit (options) files;};});
              default = {};
            };
          };
        }));
      default = {};
    };
  };
  config = let
    collections' = baile.only-enabled cfg;
    collection-configurations = attrValues (mapAttrs (_: conf: {
        inherit (conf) environment files xdg programs;
      })
      collections');

    extract-cfg = name: lib.mkMerge (map (c: c."${name}") collection-configurations);
  in {
    programs = extract-cfg "programs";
    files = extract-cfg "files";
    environment = extract-cfg "environment";
    xdg = extract-cfg "xdg";
  };
}
