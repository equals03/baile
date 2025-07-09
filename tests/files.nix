{
  name = "baile-packages";
  nodes = {
    node1 = {test-lib, ...}: {
      users.groups = {
        alice = {};
        bob = {};
      };
      users.users.alice = test-lib.mkUser {
        name = "alice";
        config = {
          programs = {
            fzf = {
              enable = true;
              config = {
                files = {
                  "fzf" = ''~/alice/fzf'';
                  ".config/fzf/fzf" = ''~alice/.config/fzf/fzf'';
                };
                xdg.state.files."fzf" = "~alice/.local/state/fzf";
              };
            };
            nushell = {
              enable = false;
              config = {
                files = {
                  "nushell" = ''~alice/nushell'';
                  ".config/nushell/nushell" = ''~alice/.config/nushell/nushell'';
                };
              };
            };
          };

          files = {
            "alice" = "~alice/alice";
            ".config/alice" = "~alice/.config/alice";
            "executable.sh" = {
              mode = "a+x";
              text = ''
                #!/usr/bin/env bash
                echo "This is an executable file"
              '';
            };
          };
          xdg.state.files."alice" = "~alice/.local/state/alice";
        };
      };

      users.users.bob = test-lib.mkUser {
        name = "bob";
        config = {
          programs = {
            fzf = {
              enable = false;
              config = {
                files = {
                  "fzf" = ''~bob/fzf'';
                  ".config/fzf/fzf" = ''~bob/.config/fzf/fzf'';
                };
                xdg.state.files."fzf" = "~bob/.local/state/fzf";
              };
            };
            nushell = {
              enable = true;
              config = {
                files = {
                  "nushell" = ''~bob/nushell'';
                  ".config/nushell/nushell" = ''~bob/.config/nushell/nushell'';
                };
                xdg.state.files."nushell" = "~bob/.local/state/nushell";
              };
            };
          };

          files = {
            "bob" = "~bob/bob";
            ".config/bob" = "~bob/.config/bob";
            "symlink" = {
              text = "symlink";
              mode = "symlink";
            };
          };
          xdg.state.files."bob" = "~bob/.local/state/bob";
          xdg.config.files."testfile" = ./data/testfile.txt;
        };
      };

      system.stateVersion = "23.11";
    };
  };

  testScript =
    #python
    ''
      def check_links_exist_with_content(links):
        for link in links:
          machine.succeed("[ -L {link} ] && [ $(cat {link}) == \"{link}\" ]".format(link=link))

      def check_links_do_not_exist(links):
        for link in links:
          machine.fail("[ -L {link} ]".format(link=link))

      machine.wait_for_unit("default.target")

      with subtest("Validating Alice..."):
        machine.succeed("[ -L ~alice/.local/state/baile/current ]")
        machine.succeed("[ -L ~alice/.local/state/baile/generation-1 ]")
        machine.succeed("[ -d ~alice/.local/state/baile/targets ]")
        check_links_exist_with_content([
          "~alice/alice",
          "~alice/.config/alice",
          "~alice/.config/fzf/fzf",
          "~alice/.local/state/fzf"
        ])
        check_links_do_not_exist([
          "~alice/bob",
          "~alice/.config/bob",
          "~alice/.config/nushell/nushell",
          "~alice/.local/state/nushell"
        ])

      with subtest("Validating Bob..."):
        machine.succeed("[ -L ~bob/.local/state/baile/current ]")
        machine.succeed("[ -L ~bob/.local/state/baile/generation-1 ]")
        machine.succeed("[ -d ~bob/.local/state/baile/targets ]")
        check_links_exist_with_content([
          "~bob/bob",
          "~bob/.config/bob",
          "~bob/.config/nushell/nushell",
          "~bob/.local/state/nushell"
        ])
        check_links_do_not_exist([
          "~bob/alice",
          "~bob/.config/alice",
          "~bob/.config/fzf/fzf",
          "~bob/.local/state/fzf"
        ])

      with subtest("Validating Source based file..."):
        machine.succeed("[ -L ~bob/.config/testfile ]")

      with subtest("Validating Symlink based file..."):
        machine.succeed("[ -d ~bob/.local/state/baile/gcroots ]")
        machine.succeed("[ -L ~bob/symlink ] && [ $(cat ~bob/symlink) == \"symlink\" ]")

      with subtest("Validating File mode..."):
        machine.succeed("[ -x $(realpath ~alice/executable.sh) ]")
    '';
}
