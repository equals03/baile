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
        config = {pkgs, ...}: {
          packages = [
            pkgs.bat
            pkgs.fish
          ];
        };
      };

      users.users.bob = test-lib.mkUser {
        name = "bob";
        config = {pkgs, ...}: {
          packages = [
            pkgs.ripgrep
          ];
        };
      };

      system.stateVersion = "23.11";
    };
  };

  testScript = ''
    machine.wait_for_unit("default.target")

    machine.succeed("su -- alice -c 'which bat'")
    machine.succeed("su -- alice -c 'which fish'")
    machine.fail("su -- alice -c 'which rg'")

    machine.fail("su -- bob -c 'which bat'")
    machine.fail("su -- bob -c 'which fish'")
    machine.succeed("su -- bob -c 'which rg'")

    machine.fail("su -- root -c 'which bat'")
    machine.fail("su -- root -c 'which fish'")
    machine.fail("su -- root -c 'which rg'")
  '';
}
