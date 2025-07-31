{
  name,
  pkgs,
  lib,
  config,
  get-program-package,
  ...
}: let
  inherit (lib) baile types;

  override-package = baile.overloaded {
    derivation = package: (
      baile.overloaded {
        lambda = package.overrideAttrs;
        set = package.override;
        null = _: package;
      }
    );
    null = _: lib.id;
  };
in {
  options = {
    package = let
      path = lib.splitString "." name;
    in
      lib.mkOption {
        type = with types; nullOr package;
        default = lib.attrByPath path null pkgs;
        apply = lib.flip override-package config.override;
      };

    extraPackages = lib.mkOption {
      type = with types; oneOf [str package (listOf (either package str))];
      default = [];
      apply = baile.compose-all [
        lib.toList
        (map get-program-package)
        lib.flatten
      ];
    };

    override = lib.mkOption {
      type = with types; uniq (nullOr (either (lazyAttrsOf unspecified) baile.types.function));
      default = null;
    };
  };
}
