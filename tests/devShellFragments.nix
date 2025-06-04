{
  pkgs,
  lib,
  system, # Now provided by nix-unit test runner (from perSystem args)
  inputs, # Now provided by nix-unit test runner (from perSystem.nix-unit.inputs)
  ...
}: let
  flake = import ./flake.nix;
  # system = pkgs.stdenv.hostPlatform.system or "x86_64-linux"; # No longer needed, use arg
  testHarnessOutputsArgs = {
    self = flake;
    nixpkgs = inputs.nixpkgs; # Sourced from nix-unit provided 'inputs'
    flake-parts = inputs.flake-parts; # Sourced from nix-unit provided 'inputs'
    latex-utils = inputs.latex-utils; # Sourced from nix-unit provided 'inputs' (aliased self)
    inherit system; # Pass the system argument to the test harness
  };
  outputs = import ./test-flake-helpers.nix {
    flakeDef = flake;
    outputsArgs = testHarnessOutputsArgs;
  };

  # According to ADR 005, shells should be available as:
  # outputs.latex-utils.${system}.unifiedTexShell
  # outputs.latex-utils.${system}.vscodeShell
  # But if transposition isn't set up, they might be packages or fail
  unifiedShell =
    if outputs ? latex-utils && outputs.latex-utils ? ${system} && outputs.latex-utils.${system} ? unifiedTexShell
    then outputs.latex-utils.${system}.unifiedTexShell
    else if outputs ? packages && outputs.packages ? ${system} && outputs.packages.${system} ? unifiedTexShell
    then outputs.packages.${system}.unifiedTexShell
    else throw "unifiedTexShell not found in outputs.latex-utils.${system} or outputs.packages.${system}";

  vscodeShell =
    if outputs ? latex-utils && outputs.latex-utils ? ${system} && outputs.latex-utils.${system} ? vscodeShell
    then outputs.latex-utils.${system}.vscodeShell
    else if outputs ? packages && outputs.packages ? ${system} && outputs.packages.${system} ? vscodeShell
    then outputs.packages.${system}.vscodeShell
    else throw "vscodeShell not found in outputs.latex-utils.${system} or outputs.packages.${system}";

  # Compose both fragments
  composedShell = pkgs.mkShell {
    inputsFrom = [unifiedShell vscodeShell];
  };

  # Helper to extract buildInputs from a mkShell
  getBuildInputs = drv:
    if drv ? buildInputs
    then drv.buildInputs
    else [];

  # Helper to extract shellHook from a mkShell
  getShellHook = drv:
    if drv ? shellHook
    then drv.shellHook
    else "";

  # Try to find texlive in buildInputs
  hasTexlive = inputs:
    lib.any (input: lib.hasInfix "texlive" (builtins.toString input)) (map builtins.toString inputs);
in {
  test_unifiedTexShell_is_package = lib.isDerivation unifiedShell;
  test_vscodeShell_is_package = lib.isDerivation vscodeShell;

  test_unifiedTexShell_has_texlive = let
    inputs = getBuildInputs unifiedShell;
  in
    lib.any (input: lib.hasInfix "texlive" (builtins.toString input)) (map builtins.toString inputs);

  test_vscodeShell_shellHook_links_settings = let
    hook = getShellHook vscodeShell;
  in
    lib.hasInfix ".vscode/settings.json" (toString hook);

  test_composedShell_is_package = lib.isDerivation composedShell;
}
