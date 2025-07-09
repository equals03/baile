{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.build;
  cfg-packages = config.packages;
in {
  config = let
    paths = lib.concatLists [
      cfg-packages
      (lib.optionals (cfg ? activationPackage) [cfg.activationPackage])
    ];
  in {
    build.toplevel = pkgs.buildEnv {
      inherit paths;
      name = "baile-path";
    };
  };
}
