{
  pkgs,
  lib,
  mainFlakeResolvedInputs, # From main flake's `outputs` args
  ...
}: let
  # Use the test harness flake defined in tests/flake.nix
  flake = import ./flake.nix;
  system = pkgs.stdenv.hostPlatform.system or "x86_64-linux";

  # These are the arguments that the test harness flake's `outputs` function expects
  testHarnessOutputsArgs = {
    self = flake; # The test harness flake itself
    inherit (mainFlakeResolvedInputs) nixpkgs flake-parts;
    # If your modules/latex-utils.nix uses specific inputs from the main flake,
    # they might need to be passed here too, e.g.:
    # latex-utils-inputs = mainFlakeResolvedInputs.latex-utils-inputs;
  };

  # Evaluate the test harness flake to get its outputs
  outputs = import ./test-flake-helpers.nix {
    flakeDef = flake;
    outputsArgs = testHarnessOutputsArgs;
  };

  # The specific devShell to test
  # This path comes from the `perSystem` output of your `modules/latex-utils.nix` flake module
  theShell = outputs.devShells.${system}.latex-utils;
in {
  # Test 1: Check if the devShell is a derivation
  test_latexUtilsShell_is_derivation = lib.isDerivation theShell;

  # Test 2: Check if it has a basic TeX Live package in its buildInputs
  # This assumes 'texlive-scheme-basic' or a similar foundational package is expected.
  # Adjust the package name if your default set is different.
  test_latexUtilsShell_has_texlive_basic_scheme =
    lib.any (p: lib.getName p == "texlive-scheme-basic") theShell.buildInputs;

  # Test 3: Check if the shellHook is a non-empty string (basic check)
  test_latexUtilsShell_has_shellHook =
    theShell ? shellHook && lib.isString theShell.shellHook && theShell.shellHook != "";

  # Add more specific tests as needed, for example:
  # - Check for specific tools (biber, latexmk, etc.)
  # - Verify contents of the shellHook if it sets up specific environment variables or messages
}
