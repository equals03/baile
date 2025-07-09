{
  pkgs,
  config,
  lib,
  ...
}: let
  cfg = config.build;
  cfg-environment = config.environment;
in {
  config = {
    build.installerPackage = let
      activation-cmd = lib.optionalString (cfg ? activationPackage) ''
        msg 'Activating profile...'
        ${lib.getExe cfg.activationPackage}
      '';

      text = ''
        # shellcheck disable=SC2059
        out() { printf "$1 $2\n" "''${@:3}"; }
        msg() { out "==>" "$@"; }

        # error() { out "==> ERROR:" "$@"; } >&2
        # warning() { out "==> WARNING:" "$@"; } >&2

        # die() { error "$@"; exit 1; }

        package="${cfg.toplevel}"
        profile_name="${cfg.toplevel.name}"
        profile_priority="${toString cfg-environment.profile.priority}"

        # Get the JSON output from nix profile list
        profile_json=$(nix profile list --json)

        msg 'Installing package %s' "$package"

        # Check if baile-path exists in the profile
        if jq '.elements | has("$profile_name")' <<<"$profile_json" | grep -q true; then
          # Get the current store path for baile-path
          msg 'An existing baile package is already installed. Checking version...'
          current_path=$(jq -r '.elements["$profile_name"].storePaths[0]' <<<"$profile_json")

          # Compare with $package
          if [ "$current_path" != "$package" ]; then
            msg 'Store path for %s (%s) differs. Updating profile.' "$profile_name" "$package"

            nvd diff "$current_path" "$package"

            # Remove the existing baile-path profile
            nix profile remove "$profile_name"
            # Install the new profile
            nix profile install --priority $profile_priority "$package"
            msg 'Successfully updated %s to %s.' "$profile_name" "$package"
          else
            msg '%s is already installed with the correct path (%s).' "$profile_name" "$package"
          fi
        else
          msg '%s not found in profile. Installing new profile.' "$profile_name"
          # Install the new profile
          nix profile install --priority $profile_priority "$package"
          msg 'Successfully installed %s with path %s.' "$profile_name" "$package"
        fi

        ${activation-cmd}

        exit 0
      '';
    in
      pkgs.writeShellApplication {
        inherit text;

        name = "baile-installer-${cfg-environment.user}";
        runtimeInputs = with pkgs; [
          gnugrep
          jq
          nvd
        ];
        meta = {
          description = "Baile installer for user ${cfg-environment.user}.";
          platforms = [pkgs.system];
          maintainers = ["equals03"];
        };
      };
  };
}
