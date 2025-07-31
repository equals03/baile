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

    sessionVariables = lib.mkOption {
      type = with types; attrsOf (oneOf [(listOf (oneOf [int str path])) int str path]);
      default = {};
      example = {
        EDITOR = "nvim";
        VISUAL = "nvim";
      };
      description = ''
        A set of environment variables used in the user environment.
        If a list of strings is used, they will be concatenated with colon
        characters.
      '';
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
