{lib, ...}: let
  inherit (lib) types;
in {
  imports = [
    ./activation.nix
    ./environment.nix
    ./files.nix
    ./systemd-environment.nix
  ];

  options = {
    build = lib.mkOption {
      type = with types; attrsOf package;
      default = {};
      internal = true;
    };
  };
}
