{
  pkgs,
  lib,
  system,
  inputs,
  ...
}: let
  flake = import ./flake.nix;
  testHarnessOutputsArgs = {
    self = flake;
    nixpkgs = inputs.nixpkgs;
    flake-parts = inputs.flake-parts;
    latex-utils = inputs.latex-utils;
    inherit system;
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
  test_unifiedTexShell_is_package = {
    expr = lib.isDerivation unifiedShell;
    expected = true;
  };

  test_vscodeShell_is_package = {
    expr = lib.isDerivation vscodeShell;
    expected = true;
  };

  test_unifiedTexShell_has_texlive = let
    inputs = getBuildInputs unifiedShell;
  in {
    expr = lib.any (input: lib.hasInfix "texlive" (builtins.toString input)) (map builtins.toString inputs);
    expected = true;
  };

  test_vscodeShell_shellHook_links_settings = let
    hook = getShellHook vscodeShell;
  in {
    expr = lib.hasInfix ".vscode/settings.json" (toString hook);
    expected = true;
  };

  test_composedShell_is_package = {
    expr = lib.isDerivation composedShell;
    expected = true;
  };
}
