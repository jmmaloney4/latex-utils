{
  description = "Test harness flake for latex-utils module output testing";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = outputsArgs @ {
    flake-parts,
    nixpkgs,
    ...
  }:
    flake-parts.lib.mkFlake {
      inputs = {
        inherit (outputsArgs) nixpkgs flake-parts latex-utils;
      };
    } {
      systems = ["x86_64-linux"];
      imports = [../modules/latex-utils.nix];
      perSystem = {
        config,
        pkgs,
        lib,
        ...
      }: {
        latex-utils.documents = [];
        # Add more minimal config if needed for specific tests
      };
    };
}
