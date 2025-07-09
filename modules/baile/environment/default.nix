{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (lib) types;

  cfg = config.environment;
in {
  imports = [
    ./activation.nix
    ./nixpkgs.nix
  ];

  options.environment = {
    user = lib.mkOption {
      type = with types; str;
    };
    home = lib.mkOption {
      type = with types; path;
      default = let
        sys = lib.systems.elaborate pkgs.system;
      in
        if sys.isDarwin
        then "/Users/${cfg.user}"
        else "/home/${cfg.user}";
    };
  };

  config = {
    assertions = [
      {
        assertion = cfg.user != "";
        message = "Username could not be determined";
      }
      {
        assertion = cfg.home != "";
        message = "Home directory could not be determined";
      }
    ];
  };
}
