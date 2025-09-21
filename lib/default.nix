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

  mkInstaller = {
    self,
    pkgs,
    lib ? pkgs.lib,
  }: let
    to-lines = lib.concatStringsSep "\n";
    profiles = lib.filterAttrs (_: profile: profile.system == pkgs.system) (self.baileConfigurations or {});
    profiles' =
      lib.mapAttrsToList (
        name: profile: ''["${lib.escapeShellArg name}"]="${lib.getExe profile.installer.program}"''
      )
      profiles;

    text = ''
      IFS=$'\n\t'
      # ANSI colour codes
      RED='\033[0;91m'
      GREEN='\033[0;92m'
      BLUE='\033[0;96m'
      WHITE='\033[0;97m'
      NO_COLOUR='\033[0m'

      prog="$(basename "$0")"

      msg()   { printf "''${WHITE}%s''${NO_COLOUR}\\n" "$*"; }
      info()  { printf "''${BLUE}%s''${NO_COLOUR}\\n" "$*"; }
      ok()    { printf "''${GREEN}%s''${NO_COLOUR}\\n" "$*"; }
      warn()  { printf "''${YELLOW}%s''${NO_COLOUR}\\n" "$*"; }
      fail()  { printf "''${RED}''${prog}: ERROR: %s [Line %s]''${NO_COLOUR}\\n" "$2" "''${1:-N/A}" >&2; exit "''${3:-1}"; }

      trap 'fail "$LINENO" "Unexpected error. Exiting."' ERR INT

      declare -A profiles=(
        ${to-lines profiles'}
      )

      lookup_profile() {
        local query="$1"
        if [[ -v profiles[$query] ]]; then
          echo "''${profiles[$query]}"
        fi
      }

      info "baile will now attempt to determine the correct profile to install..."
      for user in "$USER@$(hostname -f)" "$USER@$(hostname)" "$USER@$(hostname -s)" "$USER"; do
        info "Searching for profile: $user"

        profile=$(lookup_profile "$user")
        if [[ $profile ]]; then
          ok "Found profile: $profile"
          info "Installing profile..."
          $profile
          ok "Profile installed!"

          break
        fi
      done
    '';

    program = pkgs.writeShellApplication {
      inherit text;
      name = "baile";
      runtimeInputs = with pkgs; [coreutils];
      meta = {
        description = "Baile bootstrap installer.";
        platforms = with pkgs; [system];
        maintainers = ["equals03"];
      };
    };
  in {
    inherit program;
    type = "app";
  };
}
