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
  # Ensure perSystem itself has the devShells attribute
  topLevelDevShellsExists = {
    expr = builtins.hasAttr "devShells" perSystem;
    expected = true;
  };

  # Ensure the default devShell exists within perSystem.devShells
  defaultShellInDevShellsExists = {
    expr =
      if perSystem ? "devShells"
      then builtins.hasAttr "default" perSystem.devShells
      else false; # Fail if devShells itself is missing
    expected = true;
  };

  # Ensure the default devShell builds
  defaultShellBuilds = {
    expr =
      if perSystem ? "devShells" && perSystem.devShells ? "default"
      then perSystem.devShells.default.drvPath != null
      else false; # Fail if intermediate attrs are missing
    expected = true;
  };
}
