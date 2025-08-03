{
  config,
  lib,
  ...
}: let
  inherit (builtins) attrValues filter map;
  inherit (lib) baile types;

  cfg = config.xdg.dirs;
  cfg-environment = config.environment;
in {
  options.xdg.dirs = lib.mkOption {
    type = with types;
      attrsOf (types.submodule ({
        name,
        ...
      }: {
        options = {
          ensure = lib.mkOption {
            type = with types; bool;
            default = false;
          };
          envVariable = lib.mkOption {
            type = with types; nullOr baile.types.posix.shell-variable;
            default = "XDG_${(lib.toUpper (lib.replaceStrings ["/" " "] ["_" "_"] name))}_DIR";
          };
        };
      }));
  };

  config = let
    mkDir = env: {
      envVariable = lib.mkDefault env;
    };
    dirs = attrValues (lib.mapAttrs (_: loc: {
        inherit (loc) envVariable ensure;
        path = "${cfg-environment.home}/${loc.path}";
      })
      cfg);
  in {
    xdg.dirs = {
      cache = mkDir "XDG_CACHE_HOME";
      config = mkDir "XDG_CONFIG_HOME";
      data = mkDir "XDG_DATA_HOME";
      state = mkDir "XDG_STATE_HOME";
    };

    environment.sessionVariables = let
      with-env = filter (loc: loc.envVariable != null) dirs;
    in
      lib.listToAttrs (map (loc: {
          name = loc.envVariable;
          value = loc.path;
        })
        with-env);

    environment.activation.dag = let
      ensured = filter (loc: loc.ensure) dirs;
    in
      lib.mkIf (ensured != []) {
        ensure-xdg-dirs = let
          cmds = map (loc: ''[[ -e "${loc.path}" ]] || mkdir -p "${loc.path}"'') ensured;
        in
          baile.dag.entryAfter ["activate-files"] cmds;
      };
  };
}
