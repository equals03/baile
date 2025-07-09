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
            fzf.enable = true;
            nushell.enable = true;
          };
        };
      };

      users.users.bob = test-lib.mkUser {
        name = "bob";
        config = {
          programs = {
            bat.enable = true;
          };
        };
      };

      system.stateVersion = "23.11";
    };
  };

  testScript = ''
    machine.wait_for_unit("default.target")

    machine.succeed("su -- alice -c 'which fzf'")
    machine.succeed("su -- alice -c 'which nu'")
    machine.fail("su -- alice -c 'which bat'")

    machine.fail("su -- bob -c 'which fzf'")
    machine.fail("su -- bob -c 'which nu'")
    machine.succeed("su -- bob -c 'which bat'")

    machine.fail("su -- root -c 'which fzf'")
    machine.fail("su -- root -c 'which nu'")
    machine.fail("su -- root -c 'which bat'")
  '';
}
