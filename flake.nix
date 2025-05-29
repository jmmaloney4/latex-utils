{
  description = "Easily compile latex documents with nix flakes.";

  inputs = {
    nixpkgs.url = github:NixOS/nixpkgs/nixos-unstable;
    flake-parts.url = github:hercules-ci/flake-parts;
    systems.url = "github:nix-systems/default";
    nix-unit.url = github:nix-community/nix-unit;
  };

  outputs = inputs @ {
    flake-parts,
    nix-unit,
    systems,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = import systems;
      imports = [
        ./modules/latex-utils.nix
        inputs.nix-unit.modules.flake.default
      ];
      perSystem = {
        config,
        pkgs,
        lib,
        system,
        ...
      }: {
        nix-unit = {
          allowNetwork = true;
          tests.findLatexPackages = import ./tests/findLatexPackages.nix {
            inherit pkgs lib;
            findLatexPackages = import ./lib/findLatexPackages.nix {inherit pkgs lib;};
          };
        };
      };
      flake = {
        flakeModule = import ./modules/latex-utils.nix;
        modules.latex-utils = import ./modules/latex-utils.nix;
      };
    };
}
