# tests/test-flake-helpers.nix
# This helper just calls a flake's `outputs` function with given args.
# The `flakeDef` arg is the imported flake.nix file (e.g., import ./tests/flake.nix)
# The `outputsArgs` are the arguments that would normally be passed by Nix
# to that flake's `outputs` function (e.g., self, resolved nixpkgs, resolved flake-parts).
{
  flakeDef,
  outputsArgs,
}:
flakeDef.outputs outputsArgs
