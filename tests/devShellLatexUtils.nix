{
  pkgs,
  lib,
  system,
  inputs,
  ...
}: let
  # Use the test harness flake defined in tests/flake.nix
  flake = import ./flake.nix;

  # These are the arguments that the test harness flake's `outputs` function expects
  testHarnessOutputsArgs = {
    self = flake;
    nixpkgs = inputs.nixpkgs;
    flake-parts = inputs.flake-parts;
    latex-utils = inputs.latex-utils;
    inherit system;
  };

  # Evaluate the test harness flake to get its outputs
  outputs = import ./test-flake-helpers.nix {
    flakeDef = flake;
    outputsArgs = testHarnessOutputsArgs;
  };

  # Test the vscodeShell fragment instead of the conditional devShells.latex-utils
  # This should be available regardless of enableVSCode setting
  vscodeShell = outputs.latex-utils.${system}.vscodeShell or (throw "latex-utils.vscodeShell not found in outputs");
in {
  # Test 1: Check if the vscodeShell is a derivation
  test_vscodeShell_is_derivation = {
    expr = lib.isDerivation vscodeShell;
    expected = true;
  };

  # Test 2: Check if the vscodeShell has build inputs (texlive etc.)
  test_vscodeShell_has_inputs_from = {
    expr =
      vscodeShell ? buildInputs
      && lib.isList vscodeShell.buildInputs
      && vscodeShell.buildInputs != [];
    expected = true;
  };

  # Test 3: Check if the vscodeShell has a shellHook
  test_vscodeShell_has_shellHook = {
    expr = vscodeShell ? shellHook && lib.isString vscodeShell.shellHook && vscodeShell.shellHook != "";
    expected = true;
  };

  # Test 4: Check if buildInputs contains texlive
  test_vscodeShell_includes_texlive = let
    hasBI = vscodeShell ? buildInputs && vscodeShell.buildInputs != [];
    texlivePresent =
      hasBI
      && lib.any (p: lib.hasInfix "texlive" (lib.getName p)) vscodeShell.buildInputs;
  in {
    expr = hasBI && texlivePresent;
    expected = true;
  };
}
