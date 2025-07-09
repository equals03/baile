{
  pkgs,
  lib,
  config,
  ...
}: let
  inherit (lib) baile;

  cfg-environment = config.environment;

  no-activation = baile.without ["write-boundary"] cfg-environment.activation.dag == {};

  create-script = {
    name,
    runtimeInputs,
    dag,
  }: let
    text = let
      mkCmd = res: ''
        echo "Executing Stage: [${res.name}]"
        ${res.data}
      '';
      sorted = baile.dag.topoSort dag;
      cmds =
        if sorted ? result
        then lib.concatStringsSep "\n" (map mkCmd sorted.result)
        else abort ("Dependency cycle in ${name} script: " + (baile.pretty sorted));
    in ''
      cd "$HOME"

      ${cmds}

      exit 0
    '';
  in
    pkgs.writeShellApplication {
      inherit text runtimeInputs;

      name = "baile-${name}-${cfg-environment.user}";
      meta = {
        description = "Baile activator for user ${cfg-environment.user}.";
        platforms = [pkgs.system];
        maintainers = ["equals03"];
      };
    };
in {
  config = lib.mkIf (!no-activation) {
    build.activationPackage = create-script {
      inherit (cfg-environment.activation) runtimeInputs dag;
      name = "activate";
    };
  };
}
