{
  pkgs,
  lib,
  config,
  files',
  ...
}: let
  cfg-environment = config.environment;

  process-file-entry = file: let
    source =
      if (file.source != null)
      then file.source
      else
        (pkgs.writeTextFile {
          inherit (file) text;
          name = "baile-file-" + (lib.replaceStrings ["/"] ["-"] file.target);
        });
    target-path = "home/${cfg-environment.user}/${file.target}";
  in
    assert lib.assertMsg (lib.path.subpath.isValid target-path) "target path is not a valid subpath!"; ''
      mkdir -p $(dirname $out/${target-path}) && cp -r ${source} $out/${target-path}
    '';
in {
  config = {
    build.filesPackage = let
      commands = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (_: process-file-entry) files'
      );
    in
      pkgs.runCommand "baile-files-${cfg-environment.user}" {}
      ''
        mkdir -p $out
        ${commands}
      '';
  };
}
