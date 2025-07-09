_: {
  baileConfiguration = {
    modules ? [],
    pkgs,
    lib ? pkgs.lib,
    specialArgs ? {},
  }: let
    lib' = lib.extend (_final: prev: {
      baile = import ./baile {
        inherit pkgs;
        lib = prev;
      };
    });

    with-checks = eval: lib.asserts.checkAssertWarn eval.config.assertions eval.config.warnings eval;

    evaluated = lib.evalModules {
      specialArgs =
        {
          inherit (pkgs) system;
          lib = lib';
          hostPkgs = pkgs;
          modulesPath = toString ../modules/baile;

          osConfig = {};
          osUserConfig = {};
        }
        // specialArgs;
      class = "baile";

      modules = lib.concatLists [
        # assertions and warnings module from nixos
        [
          (pkgs.path + "/nixos/modules/misc/assertions.nix")
          ../modules/baile
          ../modules/baile/standalone
        ]
        modules
      ];
    };
  in
    (with-checks evaluated)
    // {
      inherit (pkgs) system;
      inherit (evaluated.config) build;
      inherit pkgs;

      lib = lib';
    };
}
