{
  pkgs,
  lib,
}: let
  # Import the latex-utils module
  module = import ../modules/latex-utils.nix;
  # Base config with no documents or extra packages
  baseConfig = {
    "latex-utils" = {
      documents = [];
      extraTexPackages = [];
    };
  };
  # Evaluate the module to get options and perSystem definitions
  moduleAttrs = module {
    config = baseConfig;
    pkgs = pkgs;
    lib = lib;
  };
  # Run perSystem to get outputs including devShells and config updates
  perSystem = moduleAttrs.config.perSystem {
    config = baseConfig;
    pkgs = pkgs;
    lib = lib;
  };
in {
  # Test: Check if the top-level 'devShells' attribute exists in perSystem output.
  # Purpose: Verifies that the module's perSystem evaluation produces the 'devShells' attribute set as expected.
  topLevelDevShellsExists = {
    expr = builtins.hasAttr "devShells" perSystem;
    expected = true;
  };

  # Test: Check if a 'default' development shell exists within 'perSystem.devShells'.
  # Purpose: Ensures that the standard 'default' dev shell is defined and available.
  defaultShellInDevShellsExists = {
    expr =
      if perSystem ? "devShells"
      then builtins.hasAttr "default" perSystem.devShells
      else false; # Fail if devShells itself is missing
    expected = true;
  };

  # Test: Check if the 'default' development shell is a buildable derivation.
  # Purpose: Verifies that the 'default' dev shell definition results in a valid derivation path, indicating it can be built.
  defaultShellBuilds = {
    expr =
      if perSystem ? "devShells" && perSystem.devShells ? "default"
      then perSystem.devShells.default.drvPath != null
      else false; # Fail if intermediate attrs are missing
    expected = true;
  };
}
