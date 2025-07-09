{lib, ...}: let
  inherit (lib) types;
in {
  imports = [
    ./activation.nix
    ./files.nix
  ];

  options = {
    build = lib.mkOption {
      type = with types; attrsOf package;
      default = {};
      internal = true;
    };
  };
}
