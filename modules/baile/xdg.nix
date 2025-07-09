{
  config,
  lib,
  ...
}: let
  inherit (builtins) toString;
  inherit (lib) baile types;

  cfg = config.xdg;
in {
  options.xdg = lib.mkOption {
    type = with types;
      attrsOf (types.submodule ({
        name,
        config,
        ...
      }: {
        imports = [];
        options = {
          path = lib.mkOption {
            type = with baile.types; subpath;
            default = name;
            apply = toString;
          };
          files = lib.mkOption {
            type = with types; attrsOf (baile.types.file.coerced.relative-to config.path);
            default = {};
          };
        };
      }));
  };

  config = let
    normalise = lib.mapAttrsToList (_: file: {${file.target} = file;});
    mkDir = path: {
      path = lib.mkDefault path;
    };
  in {
    xdg = {
      cache = mkDir ".cache";
      config = mkDir ".config";
      data = mkDir ".local/share";
      state = mkDir ".local/state";
    };

    files = lib.mkMerge (lib.concatLists [
      (lib.flatten (lib.mapAttrsToList (_: c: normalise c.files) cfg))
    ]);
  };
}
