{
  lib,
  config,
  ...
}: let
  inherit (lib) types;

  cfg-build = config.build;
in {
  options.systemd = lib.mkOption {
    type = with types;
      submodule ({options, ...}: {
        options = {
          sessionVariables = lib.mkOption {
            type = with types; attrsOf (oneOf [(listOf (oneOf [int str path])) int str path]);
            default = {};
            example = {
              EDITOR = "nvim";
              VISUAL = "nvim";
            };
            description = ''
              A set of environment variables used in the user session.
              If a list of strings is used, they will be concatenated with colon
              characters.
            '';
          };
        };
      });
    default = {};
  };
}
