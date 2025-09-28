_: let
  mkUser = {
    name,
    config ? {},
  }: {
    home = "/home/${name}";

    isNormalUser = true;
    password = "";

    baile = {
      imports = [
        config
      ];

      enable = true;
    };
  };
in {
  config._module.args.test-lib = {
    inherit mkUser;
  };
}
