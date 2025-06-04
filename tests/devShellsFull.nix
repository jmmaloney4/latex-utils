{
  pkgs,
  lib,
  mainFlakeResolvedInputs,
  ...
}: let
  testHarnessFlakeDef = import ./flake.nix;
  system = pkgs.stdenv.hostPlatform.system or "x86_64-linux";

  testHarnessOutputsArgs = {
    self = testHarnessFlakeDef;
    nixpkgs = mainFlakeResolvedInputs.nixpkgs;
    flake-parts = mainFlakeResolvedInputs.flake-parts;
  };

  outputs = import ./test-flake-helpers.nix {
    flakeDef = testHarnessFlakeDef;
    outputsArgs = testHarnessOutputsArgs;
  };

  fullShell = outputs.devShells.${system}.full;
  getShellHook = drv:
    if drv ? shellHook
    then drv.shellHook
    else "";
in {
  test_fullShell_is_package = lib.isDerivation fullShell;
  test_fullShell_shellHook_links_settings = let
    hook = getShellHook fullShell;
  in
    lib.hasInfix ".vscode/settings.json" (toString hook);
}
