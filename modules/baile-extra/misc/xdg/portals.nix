{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (lib) types;

  cfg = config.xdg.portal;
  portals-dir = "${config.environment.profile}/share/xdg-desktop-portal/portals";

  associationOptions = with types;
    attrsOf (coercedTo (either (listOf str) str) (x: lib.concatStringsSep ";" (lib.toList x)) str);
in {
  options.xdg.portal = {
    enable = lib.mkEnableOption "Xdg desktop integration";

    portals = lib.mkOption {
      type = with types; listOf package;
      default = [];
    };

    configPackages = lib.mkOption {
      type = with types; listOf package;
      default = [];
      example = lib.literalExpression "[ pkgs.gnome.gnome-session ]";
    };

    xdgOpenUsePortal = lib.mkOption {
      type = types.bool;
      default = false;
    };

    config = lib.mkOption {
      type = with types; attrsOf associationOptions;
      default = lib.optionalAttrs (cfg.configPackages == []) {common.default = ["*"];};
      example = {
        x-cinnamon = {
          default = [
            "xapp"
            "gtk"
          ];
        };
        pantheon = {
          default = [
            "pantheon"
            "gtk"
          ];
          "org.freedesktop.impl.portal.Secret" = ["gnome-keyring"];
        };
        common = {
          default = ["gtk"];
        };
      };
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      packages = [pkgs.xdg-desktop-portal] ++ cfg.portals ++ cfg.configPackages;
      environment.sessionVariables.NIX_XDG_DESKTOP_PORTAL_DIR = portals-dir;
    }
    (lib.mkIf cfg.xdgOpenUsePortal {
      environment.sessionVariables = {
        NIXOS_XDG_OPEN_USE_PORTAL = 1;
      };
    })
    (lib.mkIf (cfg.config != {}) {
      xdg.dirs.config.files =
        lib.concatMapAttrs (desktop: conf: {
          "xdg-desktop-portal/${lib.optionalString (desktop != "common") "$desktop-"}portals.conf" =
            lib.generators.toINI {}
            {preferred = conf;};
        })
        cfg.config;
    })
  ]);
}
