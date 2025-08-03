## this is here as an example of how to extend a program entry to be more "home-manager" like.
## no real intention to move this direction because I manage most of my configuration
## externally and I want to keep things "simple", but hey, it could be done :P
{lib, ...}: let
  inherit (lib) types;

  toConfigFile = attrs: let
    inherit (builtins) isBool attrNames;
    nonBoolFlags = lib.filterAttrs (_: v: !(isBool v)) attrs;
    enabledBoolFlags = lib.filterAttrs (_: v: isBool v && v) attrs;

    keyValuePairs =
      lib.generators.toKeyValue {
        mkKeyValue = k: v: "--${k}=${lib.escapeShellArg v}";
        listsAsDuplicateKeys = true;
      }
      nonBoolFlags;
    switches = lib.concatMapStrings (k: ''
      --${k}
    '') (attrNames enabledBoolFlags);
  in
    keyValuePairs + switches;
in {
  programs.bat = {config, ...}: let
    cfg = config;
  in {
    options = {
      settings = lib.mkOption {
        type = with types;
          attrsOf (oneOf [
            str
            (listOf str)
            bool
          ]);
        default = {};
        example = {
          theme = "TwoDark";
          pager = "less -FR";
          map-syntax = [
            "*.jenkinsfile:Groovy"
            "*.props:Java Properties"
          ];
        };
        description = ''
          Bat configuration.
        '';
      };
      themes = lib.mkOption {
        type = with types;
          attrsOf (
            submodule {
              options = {
                src = lib.mkOption {
                  type = path;
                  description = "Path to the theme folder.";
                };

                file = lib.mkOption {
                  type = nullOr str;
                  default = null;
                  description = "Subpath of the theme file within the source, if needed.";
                };
              };
            }
          );
        default = {};
        example = lib.literalExpression ''
          {
            dracula = {
              src = pkgs.fetchFromGitHub {
                owner = "dracula";
                repo = "sublime"; # Bat uses sublime syntax for its themes
                rev = "26c57ec282abcaa76e57e055f38432bd827ac34e";
                sha256 = "019hfl4zbn4vm4154hh3bwk6hm7bdxbr1hdww83nabxwjn99ndhv";
              };
              file = "Dracula.tmTheme";
            };
          }
        '';
        description = ''
          Additional themes to provide.
        '';
      };

      syntaxes = lib.mkOption {
        type = with types;
          attrsOf (
            submodule {
              options = {
                src = lib.mkOption {
                  type = path;
                  description = "Path to the syntax folder.";
                };
                file = lib.mkOption {
                  type = nullOr str;
                  default = null;
                  description = "Subpath of the syntax file within the source, if needed.";
                };
              };
            }
          );
        default = {};
        example = lib.literalExpression ''
          {
            gleam = {
              src = pkgs.fetchFromGitHub {
                owner = "molnarmark";
                repo = "sublime-gleam";
                rev = "2e761cdb1a87539d827987f997a20a35efd68aa9";
                hash = "sha256-Zj2DKTcO1t9g18qsNKtpHKElbRSc9nBRE2QBzRn9+qs=";
              };
              file = "syntax/gleam.sublime-syntax";
            };
          }
        '';
        description = ''
          Additional syntaxes to provide.
        '';
      };
    };

    config = lib.mkIf cfg.enable {
      xdg.dirs =
        lib.mkMerge
        (
          [(lib.mkIf (cfg.settings != {}) {config.files."bat/config" = toConfigFile cfg.settings;})]
          ++ (lib.flip lib.mapAttrsToList cfg.themes (
            name: val: {
              config.files."bat/themes/${name}.tmTheme" = {
                source =
                  if (val.file == null)
                  then "${val.src}"
                  else "${val.src}/${val.file}";
              };
            }
          ))
          ++ (lib.flip lib.mapAttrsToList cfg.syntaxes (
            name: val: {
              config.files."bat/syntaxes/${name}.sublime-syntax" = {
                source =
                  if (val.file == null)
                  then "${val.src}"
                  else "${val.src}/${val.file}";
              };
            }
          ))
        );
    };
  };
}
