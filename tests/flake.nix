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

      # Module-level options (not per-system)
      latex-utils.documents = [];
      # Add other module-level configuration as needed

      perSystem = {
        config,
        pkgs,
        lib,
        ...
      }: {
        # Per-system configuration can go here
        # The latex-utils.unifiedTexShell and latex-utils.vscodeShell will be
        # automatically populated by the module and available via config.latex-utils.*
      };
    };
}
