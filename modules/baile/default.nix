{...}: {
  imports = [
    ./activators

    ./build
    ./environment

    ./files.nix
    ./packages.nix
    #./programs.nix
    ./programs
    ./xdg.nix
  ];
}
