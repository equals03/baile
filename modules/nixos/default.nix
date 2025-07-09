{
  config,
  pkgs,
  lib,
  specialArgs,
  modulesPath,
  ...
}: let
  inherit (lib) types;

  osConfig = config;

  baile' = lib.flip lib.filterAttrs config.users.users (_: cfg: cfg.enable && cfg.baile.enable);

  lib' = lib.extend (_final: prev: {
    baile = import ../../lib/baile {
      inherit pkgs;
      lib = prev;
    };
  });

  to-activation-service = name: userConfig: let
    inherit (userConfig) baile;
    identifier = "baile-activate-${name}";
  in
    lib.optionalAttrs (baile.build ? activationPackage) {
      "${identifier}" = {
        description = "Baile activation service for ${baile.environment.user}";

        wantedBy = ["multi-user.target"];
        wants = ["nix-daemon.socket"];
        after = ["nix-daemon.socket"];
        before = ["systemd-user-sessions.service"];

        unitConfig = {
          RequiresMountsFor = baile.environment.home;
        };

        serviceConfig = {
          User = baile.environment.user;
          Type = "oneshot";
          TimeoutSec = "5m";
          SyslogIdentifier = identifier;

          ExecStart = lib.getExe baile.build.activationPackage;
        };
      };
    };
in {
  options.users.users = lib.mkOption {
    type = with types;
      attrsOf (submodule ({
        name,
        config,
        ...
      }: let
        osUserConfig = config;
      in {
        options.baile = lib.mkOption {
          description = "Baile NixOS module";
          type = lib'.baile.mkDeferredModuleType ({config, ...}: {
            _file = ./default.nix;
            options = {
              enable =
                lib.mkEnableOption "baile"
                // {
                  default = osUserConfig.enable && osUserConfig.isNormalUser;
                };
            };
            config = {
              environment.user = lib.mkDefault osUserConfig.name;
              environment.home = lib.mkDefault osUserConfig.home;
            };
          });
          default = {};
          apply = modules:
            (lib.evalModules {
              modules =
                [
                  (modulesPath + "/misc/assertions.nix")
                  ../baile
                ]
                ++ (lib.toList modules);
              prefix = ["users" "users" name "baile"];
              specialArgs =
                specialArgs
                // {
                  inherit osConfig osUserConfig;
                  hostPkgs = pkgs;
                  modulesPath = toString ../baile;
                  lib = lib';
                };
              class = "baile";
            }).config;
        };

        config = lib.mkIf osUserConfig.baile.enable {
          packages = with osUserConfig.baile;
            lib.concatLists [
              packages
              (lib.optionals (build ? activationPackage) [build.activationPackage])
            ];
        };
      }));
  };

  config = lib.mkMerge [
    (lib.mkIf (baile' != {}) {
      environment.pathsToLink = ["/etc/profile.d"];

      systemd.services = lib.mkMerge (
        lib.mapAttrsToList to-activation-service baile'
      );

      warnings = lib.flatten (
        lib.mapAttrsToList (user: config: map (warning: "${user} baile profile: ${warning}") config.baile.warnings) baile'
      );

      assertions = lib.flatten (
        lib.mapAttrsToList (
          user: config: (map (assertion: {
              inherit (assertion) assertion;
              message = "${user} baile profile: ${assertion.message}";
            })
            config.baile.assertions)
        )
        baile'
      );
    })
  ];
}
