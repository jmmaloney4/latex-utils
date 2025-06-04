{
  pkgs,
  lib,
  system, # Now provided by nix-unit test runner (from perSystem args)
  inputs, # Now provided by nix-unit test runner (from perSystem.nix-unit.inputs)
  ...
}: let
  # Use the test harness flake defined in tests/flake.nix
  flake = import ./flake.nix;
  # system = pkgs.stdenv.hostPlatform.system or "x86_64-linux"; # No longer needed, use arg

  # These are the arguments that the test harness flake's `outputs` function expects
  testHarnessOutputsArgs = {
    self = flake;
    nixpkgs = inputs.nixpkgs; # Sourced from nix-unit provided 'inputs'
    flake-parts = inputs.flake-parts; # Sourced from nix-unit provided 'inputs'
    latex-utils = inputs.latex-utils; # Sourced from nix-unit provided 'inputs' (aliased self)
    inherit system; # Pass the system argument to the test harness
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
  test_vscodeShell_is_derivation = lib.isDerivation vscodeShell;

  # Test 2: Check if the vscodeShell has TeX Live content in inputsFrom
  test_vscodeShell_has_inputs_from =
    vscodeShell ? inputsFrom && lib.isList vscodeShell.inputsFrom && vscodeShell.inputsFrom != [];

  # Test 3: Check if the vscodeShell has a shellHook
  test_vscodeShell_has_shellHook =
    vscodeShell ? shellHook && lib.isString vscodeShell.shellHook && vscodeShell.shellHook != "";

  # Test 4: Check if first inputsFrom item has texlive in buildInputs
  test_vscodeShell_includes_texlive = let
    hasInputsFrom = vscodeShell ? inputsFrom && vscodeShell.inputsFrom != [];
    firstInput =
      if hasInputsFrom
      then builtins.head vscodeShell.inputsFrom
      else null;
    hasTexLive =
      firstInput
      != null
      && firstInput ? buildInputs
      && lib.any (p: lib.hasInfix "texlive" (lib.getName p)) firstInput.buildInputs;
  in
    hasInputsFrom && hasTexLive;

  # Add more specific tests as needed, for example:
  # - Check for specific tools (biber, latexmk, etc.)
  # - Verify contents of the shellHook if it sets up specific environment variables or messages
}
