{
  lib,
  get-program-package,
  ...
}: let
  inherit (lib) baile types;

  coerced-string-type = with types;
    coercedTo (oneOf [str lines (listOf str)]) (baile.overloaded {
      list = lib.concatStringsSep "\n";
      default = lib.id;
    })
    str;

  activation-type = with types;
    submodule ({...}: {
      options = {
        dag = lib.mkOption {
          type = baile.types.dag.of coerced-string-type;
          default = {};
        };
        runtimeInputs = lib.mkOption {
          type = with types; listOf (either str package);
          default = [];
          apply = map get-program-package;
        };
      };
    });
in {
  options.environment = {
    activation = lib.mkOption {
      type = activation-type;
      default = {};
    };
  };

  config = {
    environment.activation = {
      runtimeInputs = ["coreutils" "nix"];
      dag.write-boundary = lib.baile.dag.entryAnywhere [
        ''
          # This is a write boundary.
          # No file system mutations should occur before this point.
        ''
      ];
    };
  };
}
