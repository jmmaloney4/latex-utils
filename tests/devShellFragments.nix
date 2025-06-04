{
  pkgs,
  lib,
  mainFlakeResolvedInputs, # From main flake's `outputs` args
  ...
}: let
  flake = import ./flake.nix;
  system = pkgs.stdenv.hostPlatform.system or "x86_64-linux";
  testHarnessOutputsArgs = {
    self = flake;
    nixpkgs = mainFlakeResolvedInputs.nixpkgs;
    flake-parts = mainFlakeResolvedInputs.flake-parts;
  };
  outputs = import ./test-flake-helpers.nix {
    flakeDef = flake;
    outputsArgs = testHarnessOutputsArgs;
  };
  unifiedShell = outputs.latex-utils.${system}.unifiedTexShell;
  vscodeShell = outputs.latex-utils.${system}.vscodeShell;
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
