{
  description = "Test harness flake for latex-utils module output testing";

  inputs = {
    # These are the declared inputs of the test harness flake itself.
    # They will be satisfied by the `inputs` attribute set constructed below
    # from `evalArgs`.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    # `latex-utils` is NOT declared here as an input URL, because it's dynamically passed
    # from the main flake's `self` reference.
  };

  outputs = evalArgs @ {
    self,
    nixpkgs,
    flake-parts,
    latex-utils,
    ...
  }:
  # `evalArgs` are the arguments passed from the test file (testHarnessOutputsArgs)
  # - evalArgs.self is the definition of this test harness flake
  # - evalArgs.nixpkgs is the actual nixpkgs flake
  # - evalArgs.flake-parts is the actual flake-parts flake
  # - evalArgs.latex-utils is the main latex-utils project flake
    flake-parts.lib.mkFlake {
      inherit self; # Use `evalArgs.self` as the `self` for this mkFlake call
      inputs = {
        # Construct the `inputs` attrset that the imported module will see
        inherit nixpkgs flake-parts latex-utils; # These come from evalArgs
      };
    } {
      systems = ["x86_64-linux"]; # Or could be parameterized from evalArgs if needed

      imports = [
        ../modules/latex-utils.nix # The module under test
      ];

      # Configure the imported `latex-utils` module as needed for the tests
      latex-utils.documents = [];
      latex-utils.enableVSCode = true;
      # Add any other minimal configuration required for the module to produce
      # the outputs being tested.

      perSystem = {
        pkgs,
        config,
        lib,
        system,
        inputs',
        ...
      }: {
        # This is the perSystem block for the test harness flake itself.
        # `inputs'` here will correctly reference the flakes provided above:
        # - inputs'.nixpkgs will be the actual nixpkgs flake.
        # - inputs'.flake-parts will be the actual flake-parts flake.
        # - inputs'.latex-utils will be the main project flake.
        #
        # The latex-utils module's outputs (e.g., config.latex-utils.vscodeShell)
        # will be evaluated here and then mapped by flake-parts to the
        # final outputs of this test harness flake (e.g., outputs.latex-utils.x86_64-linux.vscodeShell).
      };
    };
}
