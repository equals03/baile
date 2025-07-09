{
  lib,
  config,
  ...
}: let
  inherit (builtins) length;
  inherit (lib) baile types;

  cfg = config.files;

  files' = baile.only-enabled cfg;
in {
  options = {
    files = lib.mkOption {
      type = with types; attrsOf baile.types.file.coerced.type;
      default = {};
    };
  };
  config = {
    _module.args = {
      inherit files';
    };

    assertions = let
      missing = lib.attrNames (lib.filterAttrs (_: file: file.text == null && file.source == null) files');
      dups = lib.filterAttrs (_: group: (length group) > 1) (lib.groupBy (file: file.target) (lib.attrValues files'));
    in [
      {
        assertion = missing == [];
        message = "The following have both 'source' and 'text' unset. At least one needs to be specified:\n  ${lib.concatStringsSep ", " missing}";
      }
      {
        assertion = dups == {};
        message = ''
          Conflicting managed target files:
            ${lib.concatStringsSep ", " (lib.attrNames dups)}

          This may happen, for example, if you have a configuration similar to

              files = {
                conflict1 = { source = ./foo.nix; target = "baz"; };
                conflict2 = { source = ./bar.nix; target = "baz"; };
              }'';
      }
    ];
  };
}
