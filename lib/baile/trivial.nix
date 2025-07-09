{
  lib,
  baile,
  ...
}: {
  only-enabled = baile.overloaded {
    set = lib.filterAttrs (_: v: v.enable or false);
    list = lib.filter (v: v.enable or false);
  };

  pretty = lib.generators.toPretty {};

  get-source-store-path = path: let
    source-path = toString path;
    source-name = lib.replaceStrings ["/"] ["-"] source-path;
  in
    if builtins.hasContext source-path
    then path
    else
      builtins.path {
        inherit path;
        name = source-name;
      };
}
