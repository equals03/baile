{lib, ...}: let
  inherit (lib) types;
in {
  options = {
    packages = lib.mkOption {
      type = with types; listOf package;
      default = [];
      apply = lib.unique;
    };
  };
}
