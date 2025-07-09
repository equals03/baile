{
  pkgs,
  config,
  lib,
  files',
  get-program-package,
  ...
}: let
  inherit (lib) baile types;

  cfg = config.environment.activators.stow;
  cfg-build = config.build;
  cfg-environment = config.environment;
  cfg-xdg = config.xdg;

  files-package = cfg-build.filesPackage;
  state-dir = "${cfg-environment.home}/${cfg-xdg.state.path}/baile";

  stow-activation = let
    should-gc-root = builtins.any (file: file.mode == "symlink") (builtins.attrValues files');

    mkCopyCmd = file:
      ''install_file "${file.target}"''
      + lib.optionalString (file.mode != null) " \"${file.mode}\"";
    copy-cmds = lib.concatStringsSep "\n  " (lib.flatten (builtins.map mkCopyCmd (builtins.attrValues files')));
    max-keep = lib.optionalString (cfg.settings.maxGenerations != null) (toString cfg.settings.maxGenerations);
  in
    pkgs.writeShellApplication {
      runtimeInputs = map get-program-package ["coreutils" "stow"];
      text = ''
        NIX_PACKAGE_PATH="${files-package}"
        NIX_PACKAGE_NAME="${builtins.baseNameOf files-package}"

        STATE_DIR="${state-dir}"

        SOURCE_DIR="$NIX_PACKAGE_PATH/home/${cfg-environment.user}"

        TARGETS_DIR="$STATE_DIR/targets"
        TARGET_DIR="$TARGETS_DIR/$NIX_PACKAGE_NAME"

        FINAL_DIR="$STATE_DIR/current"

        GCROOT_DIR="$STATE_DIR/gcroots"
        GCROOT_LINK="$GCROOT_DIR/$NIX_PACKAGE_NAME"
        GCROOT_REQUIRED=${toString should-gc-root}

        MAX_KEEP=${max-keep}
        GEN_PREFIX="generation"

        # === Function to install a file ===
        # Usage: install_file <relative_path> [mode]
        install_file() {
          local rel_path="$1"
          local mode="''${2:-}"

          local src="$SOURCE_DIR/$rel_path"
          local dst="$TARGET_DIR/$rel_path"

          mkdir -p "$(dirname "$dst")"
          if [ "$mode" = "symlink" ]; then
            # === Stow doesn't handle absolute symlinks, so we convert it to relative symlinks ===
            ln -sfn "$(realpath --relative-to="$(dirname "$dst")" "$src")" "$dst"
          else
            cp -v --no-preserve=all --recursive "$src" "$dst"
            if [ -n "$mode" ] && [ -e "$dst" ]; then
              chmod "$mode" "$dst"
            fi
          fi
        }

        # === Register generation and update current ===
        register_generation() {
          local next_gen=1
          local new_link=""

          for f in "$STATE_DIR/$GEN_PREFIX"-*; do
            [ -e "$f" ] || continue
            n="''${f##*-}"
            if [ "$n" -ge "$next_gen" ] 2>/dev/null; then
              next_gen=$((n + 1))
            fi
          done

          new_link="$STATE_DIR/$GEN_PREFIX-$next_gen"
          ln -sfn "$TARGET_DIR" "$new_link"
          ln -sfn "$(basename "$new_link")" "$FINAL_DIR"
          echo "Registered $new_link as new generation, and updated current"

          # === GC root registration if needed ===
          if [ "''${GCROOT_REQUIRED:-0}" -eq 1 ]; then
            mkdir -p "$GCROOT_DIR"
            echo "Creating GC root for store path: $SOURCE_DIR"
            nix-store --add-root "$GCROOT_LINK" --indirect --realise "$NIX_PACKAGE_PATH"
          fi
        }

        # === GC generations beyond $MAX_KEEP, preserving current ===
        gc_generations() {
          echo "Running GC (keeping latest $MAX_KEEP generations)..."

          # === Get all generation symlinks sorted by generation number ===
          mapfile -t all_gens < <(
            find "$STATE_DIR" -maxdepth 1 -type l -name "$GEN_PREFIX-*" 2>/dev/null | \
            sort -t'-' -k2 -n
          )

          # === Resolve current target
          local current_target
          current_target=$(readlink -f "$FINAL_DIR")
          local gens_to_keep=()
          local targets_to_keep=()

          # === Keep last N generations ===
          local total=''${#all_gens[@]}
          local start=$(( total > MAX_KEEP ? total - MAX_KEEP : 0 ))
          for ((i = start; i < total; i++)); do
            gens_to_keep+=("''${all_gens[i]}")
            targets_to_keep+=("$(readlink -f "''${all_gens[i]}")")
          done
          targets_to_keep+=("$current_target")

          # === Delete old symlinks ===
          for gen in "''${all_gens[@]}"; do
            keep=0
            for g in "''${gens_to_keep[@]}"; do
              [ "$gen" = "$g" ] && keep=1 && break
            done
            if [ "$keep" -eq 0 ]; then
              echo "Pruning $(basename "$gen")"
              rm -f "$gen"
            fi
          done

          # === Delete unreferenced target directories ===
          for dir in "$TARGETS_DIR"/*; do
            [ -d "$dir" ] || continue
            local dir_resolved
            dir_resolved=$(readlink -f "$dir")
            keep=0
            for tgt in "''${targets_to_keep[@]}"; do
              [ "$dir_resolved" = "$tgt" ] && keep=1 && break
            done
            if [ "$keep" -eq 0 ]; then
              echo "Removing unreferenced target: $(basename "$dir")"
              rm -rf "$dir"
            fi
          done

          # === Clean up orphaned GC roots ===
          for root in "$GCROOT_DIR"/*; do
            [ -L "$root" ] || continue

            local root_name
            root_name=$(basename "$root")
            if [ ! -d "$TARGETS_DIR/$root_name" ]; then
              echo "Removing GC root: $root_name"
              rm -f "$root"
            fi
          done
        }

        # === Begin Execution ===

        # === Store current symlink (if exists) ===
        previous=""
        if [ -L "$FINAL_DIR" ]; then
          previous=$(readlink -f "$FINAL_DIR")
        fi

        if [ "$previous" == "$TARGET_DIR" ]; then
          echo "Generation is already active. No changes made."
          exit 0
        fi

        # === Copy files to target (if it doesn't exist) ===
        if [ ! -d "$TARGET_DIR" ]; then
          mkdir -p "$TARGET_DIR"
          ${copy-cmds}
        fi

        # === Register the generation and update current symlink ===
        register_generation

        # === Restow the package ===
        SUCCESS=0
        if ! stow -R --no-folding --dir="$STATE_DIR" --target="${cfg-environment.home}" current; then
          SUCCESS=$?
        fi

        # === Check for success and revert if necessary ===
        if [ "$SUCCESS" -ne 0 ]; then
          echo "Stow failed; reverting to previous generation (if any)."
          if [ -n "$previous" ]; then
            ln -sfn "$previous" "$FINAL_DIR"
            echo "Reverted to previous target: $(basename "$previous")"
          else
            echo "No previous generation to revert to."
          fi
        fi

        # === Run garbage collection if MAX_KEEP is set and greater than 0 ===
        if [ "$SUCCESS" -eq 0 ] && [ -n "''${MAX_KEEP:-}" ] && [ "$MAX_KEEP" -gt 0 ]; then
          gc_generations
        fi
      '';

      name = "baile-stow-${cfg-environment.user}";
      meta = {
        description = "Baile stow files activator for user ${cfg-environment.user}.";
        platforms = [pkgs.system];
        maintainers = ["equals03"];
      };
    };
in {
  options = {
    environment.activators.stow = {
      enable =
        lib.mkEnableOption "stow activator"
        // {
          default = true;
        };
      settings = {
        maxGenerations = lib.mkOption {
          type = with types; nullOr int;
          default = 5;
        };
      };
    };
  };

  config = lib.mkIf (cfg.enable) {
    build.stowActivationPackage = stow-activation;
    environment.activation.dag = {
      activate-files = baile.dag.entryAfter ["write-boundary"] ''
        # === Copy and Stow home files ===
        ${lib.getExe stow-activation}
      '';
    };
  };
}
