{lib, ...}: let
  inherit
    (builtins)
    attrNames
    concatStringsSep
    removeAttrs
    typeOf
    throw
    ;
in rec {
  maybe-call = fn: let
    is-function = lib.isFunction fn;
  in
    x:
      if is-function
      then fn x
      else fn;

  # even though nixpkgs explicity says not too ;)
  compose-all = lib.flip lib.pipe;

  without = compose-all [
    lib.toList
    (lib.flip removeAttrs)
  ];

  overloaded = cases: let
    expected = attrNames (without "default" (lib.filterAttrs (_: v: v != null) cases));
    err = type: value:
      lib.addErrorContext "while evaluating overloaded function" (throw
        ''
          unexpected argument type:
                  expected -> ${concatStringsSep ", " expected}
                  received -> ${type} (${lib.generators.toPretty {} value})
        '');
    overloadedFn = arg: let
      typeOf-arg =
        if (lib.isDerivation arg)
        then "derivation" # special case; worth supporting
        else typeOf arg;
      case = cases."${typeOf-arg}" or (cases.default or (err typeOf-arg));
      fn =
        if case != null
        then case
        else (err typeOf-arg);
    in
      maybe-call fn arg;
  in
    overloadedFn;
}
