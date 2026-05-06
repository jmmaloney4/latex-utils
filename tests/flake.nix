{
  description = "Test harness flake for latex-utils module output testing";

  # These URL declarations are ignored at runtime — they exist so that
  # `nix flake check` and other tooling can parse this as a valid flake.
  # The actual resolved flakes are passed via `outputsArgs` and patched
  # onto `self.inputs` inside `mkFlake`.
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = evalArgs @ {
    self,
    nixpkgs,
    flake-parts,
    latex-utils,
    system,
    ...
  }:
  # evalArgs come from testHarnessOutputsArgs in each test file.
  # - evalArgs.self     = this file (imported as a Nix expression)
  # - evalArgs.nixpkgs  = the resolved nixpkgs flake
  # - evalArgs.flake-parts = the resolved flake-parts flake
  # - evalArgs.latex-utils = the latex-utils project flake
  # - evalArgs.system   = current system (e.g., aarch64-darwin)
    flake-parts.lib.mkFlake {
      # Override self so that self.inputs contains resolved flake objects.
      # The raw `self` from `import ./flake.nix` has URL-string inputs,
      # which crash when flake-parts computes `inputs'` (it iterates
      # self.inputs and calls rootConfig.perInput on each entry).
      self = self // {
        inputs = {
          inherit nixpkgs flake-parts latex-utils;
        };
      };
    } {
      systems = [system];

      imports = [
        ../modules/latex-utils.nix
      ];

      latex-utils.documents = [];
      latex-utils.enableVSCode = true;

      perSystem = {pkgs, ...}: {};
    };
}
