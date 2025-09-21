{...}: {
  imports = [
    ./activators

    ./build
    ./environment

    ./files.nix
    ./packages.nix

    ./programs
    ./xdg.nix
    ./systemd.nix
  ];
}
