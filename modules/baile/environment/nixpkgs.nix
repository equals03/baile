{
  lib,
  config,
  hostPkgs,
  ...
}: let
  inherit (lib) types;

  cfg = config.environment.nixpkgs;

  overlay-type = lib.mkOptionType {
    name = "nixpkgs-overlay";
    description = "nixpkgs overlay";
    check = lib.isFunction;
    merge = lib.mergeOneOption;
  };
  pkgs-type =
    types.pkgs
    // {
      # This type is only used by itself, so let's elaborate the description a bit
      # for the purpose of documentation.
      description = "An evaluation of Nixpkgs; the top level attribute set of packages";
    };
in {
  options.environment = {
    nixpkgs = {
      overlays = lib.mkOption {
        default = [];
        type = with types; listOf overlay-type;
      };

      pkgs = lib.mkOption {
        type = pkgs-type;
        default = hostPkgs;
        apply = pkgs:
          if cfg.overlays != []
          then pkgs.appendOverlays cfg.overlays
          else pkgs;
      };
    };
  };

  config._module.args.pkgs = lib.mkOverride lib.modules.defaultOverridePriority cfg.pkgs;
}
