{lib, ...}: let
  inherit (lib) types;
in {
  options.environment = {
    profile = {
      priority = lib.mkOption {
        type = with types; ints.positive;
        default = 5;
      };
    };
  };
}
