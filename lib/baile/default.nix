{
  lib,
  ...
} @ args: let
  import-module = lib.flip import (args // {inherit baile;});

  baile = lib.foldr (l: r: l // r) {} [
    (import-module ./dag.nix)
    (import-module ./fn.nix)
    (import-module ./trivial.nix)
    (import-module ./types.nix)
  ];
in
  baile
