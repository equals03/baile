{
  lib,
  baile,
  ...
}: let
  inherit (builtins) readFileType;
  inherit (lib) types;

  make-relative = relative-to: path:
    if (relative-to == "" || relative-to == null)
    then path
    else "${relative-to}/${path}";

  try-read-file-type = path:
    if path != null && (lib.pathExists path)
    then (readFileType path)
    else "regular";

  is-path = baile.overloaded {
    string = s: types.path.check s;
    path = _: true;
  };

  to-file = baile.overloaded {
    string = s:
      if (is-path s)
      then {source = s;}
      else {text = s;};
    path = source: {inherit source;};
  };

  coerced-file-type = relative-to: with types; (coercedTo (either str path) to-file (file-type relative-to));

  subpath-type = let
    base = types.pathWith {
      inStore = false;
      absolute = false;
    };
  in
    base
    // {
      description = "subpath";
      check = path: (base.check path) && (lib.path.subpath.isValid path);
    };

  file-type = relative-to: let
    file-mode = let
      pattern = "^([ugoa]*([-+=]([rwxXst]*|[ugo]))+|[-+=][0-7]+)(,([ugoa]*([-+=]([rwxXst]*|[ugo]))+|[-+=][0-7]+))*$";
    in
      lib.mkOptionType {
        name = "fileMode";
        description = "chmod-like compatible mode string";
        descriptionClass = "noun";
        check = x: types.str.check x && builtins.match pattern x != null;
      };
  in
    with types;
      submodule (
        {
          name,
          config,
          options,
          ...
        }: {
          options = {
            enable = lib.mkOption {
              type = with types; bool;
              default = true;
              description = ''
                Whether this /etc file should be generated.  This
                option allows specific /etc files to be disabled.
              '';
            };

            target = lib.mkOption {
              type = subpath-type;
              default = name;
              description = ''
                Name of file (relative to
                {file}`~/`).  Defaults to the attribute
                name.
              '';
              apply = let
                check = path:
                  if (lib.hasPrefix "/" path)
                  then throw "absolute paths are not supported"
                  else path;
              in
                baile.compose-all [
                  check
                  (make-relative relative-to)
                  lib.path.subpath.normalise
                  (lib.removePrefix "./")
                ];
            };

            text = lib.mkOption {
              default = null;
              type = with types; nullOr lines;
              description = "Text of the file.";
            };

            source = lib.mkOption {
              default = null;
              type = with types; nullOr path;
              description = "Path of the source file.";
            };

            mode = lib.mkOption {
              #type = with types; nullOr (either (strMatching "^([ugoa]*([-+=]([rwxXst]*|[ugo]))+|[-+=][0-7]+)(,([ugoa]*([-+=]([rwxXst]*|[ugo]))+|[-+=][0-7]+))*$") (strMatching "^symlink$"));
              type = with types; nullOr (either file-mode (strMatching "^symlink$"));
              default = null;
              example = "u+w,g-w,o=r";
            };

            kind = lib.mkOption {
              type = with types; str;
              default = try-read-file-type config.source;
            };
          };
        }
      );

  function-type = lib.mkOptionType {
    name = "function";
    description = "a function";
    check = lib.isFunction;
  };

  # file-mode = let
  #   octal = types.strMatching "^[0-7]{3,4}$";
  #   symbolic = types.strMatching "^[+-][rwx]{1,9}$";
  #   symlink = types.strMatching "^symlink$";
  #   # octal = lib.mkOptionType {
  #   #   name = "octal";
  #   #   type = with types; strMatching "^[0-7]{3,4}$";
  #   #   description = "Octal representation of a file mode, e.g. '0644' or '0755'.";
  #   #   merge = loc: defs: defs; # no merging
  #   # };
  #   # symbolic = lib.mkOptionType {
  #   #   name = "symbolic";
  #   #   type = with types; strMatching "^[+-][rwx]{1,9}$";
  #   #   description = "Symbolic representation of a file mode, e.g. 'rwxr-xr--'.";
  #   #   merge = loc: defs: defs; # no merging
  #   # };
  #   # symlink = lib.mkOptionType {
  #   #   name = "symlink";
  #   #   type = with types; strMatching "^symlink$";
  #   #   description = "A symlink, e.g. 'symlink'.";
  #   #   merge = loc: defs: defs; # no merging
  #   # };
  # in
  #   lib.mkOptionType {
  #     name = "fileMode";
  #     type = with types; either octal symbolic symlink;
  #     description = "File mode, e.g. '0644' or '0755'.";
  #     merge = loc: defs: defs; # no merging
  #     emptyValue = null;
  #   };

  dag-entry-type = elem-type: let
    dag-submodule-type = types.submodule (
      {name, ...}: {
        options = {
          data = lib.mkOption {type = elem-type;};
          after = lib.mkOption {
            type = with types; listOf str;
            apply = lib.unique;
          };
          before = lib.mkOption {
            type = with types; listOf str;
            apply = lib.unique;
          };
        };
        config = lib.mkIf (elem-type.name == "submodule") {
          data._module.args.dagName = name;
        };
      }
    );
    maybeConvert = def:
      if baile.dag.isEntry def.value
      then def.value
      else
        baile.dag.entryAnywhere (
          if def ? priority
          then lib.mkOrder def.priority def.value
          else def.value
        );
  in
    lib.mkOptionType {
      name = "dagEntryOf";
      description = "DAG entry of ${elem-type.description}";
      # leave the checking to the submodule type
      merge = loc: defs:
        dag-submodule-type.merge loc (
          map (def: {
            inherit (def) file;
            value = maybeConvert def;
          })
          defs
        );
    };

  dag-type = elem-type: let
    attrEquivalent = types.attrsOf (dag-entry-type elem-type);
  in
    lib.mkOptionType rec {
      name = "dagOf";
      description = "DAG of ${elem-type.description}";
      inherit (attrEquivalent) check merge emptyValue;
      getSubOptions = prefix: elem-type.getSubOptions (prefix ++ ["<name>"]);
      inherit (elem-type) getSubModules;
      substSubModules = m: dag-type (elem-type.substSubModules m);
      functor =
        (lib.defaultFunctor name)
        // {
          wrapped = elem-type;
        };
      nestedTypes.elemType = elem-type;
    };
in {
  mkDeferredModuleType = module:
    types.deferredModuleWith {
      staticModules = [module];
    };

  types = {
    file = {
      type = file-type null;
      relative-to = file-type;
      coerced = {
        type = coerced-file-type null;
        relative-to = coerced-file-type;
      };
    };

    dag = {
      type = dag-type types.unspecified;
      of = dag-type;
    };

    subpath = subpath-type;
    function = function-type;
  };
}
