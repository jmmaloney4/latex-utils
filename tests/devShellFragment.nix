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
  moduleAttrs = module { config = baseConfig; pkgs = pkgs; lib = lib; };
  # Run perSystem to get outputs including devShells and config updates
  perSystem = moduleAttrs.config.perSystem { config = baseConfig; pkgs = pkgs; lib = lib; };
in {
  # Ensure the devShell option is defined in options.latex-utils
  optionDevShellDefined = {
    expr = builtins.hasAttr "devShell" moduleAttrs.options."latex-utils";
    expected = true;
  };

  # Ensure the composite devShell fragment exists in the generated config
  fragmentExists = {
    expr = builtins.hasAttr "devShell" perSystem.config."latex-utils";
    expected = true;
  };

  # Ensure the devShell fragment builds
  fragmentBuilds = {
    expr = perSystem.config."latex-utils".devShell.drvPath != null;
    expected = true;
  };

  # Ensure the vscode devShell was composed and exists
  vscodeShellExists = {
    expr = builtins.hasAttr "vscode" perSystem.devShells;
    expected = true;
  };

  # Ensure the vscode devShell builds
  vscodeShellBuilds = {
    expr = perSystem.devShells.vscode.drvPath != null;
    expected = true;
  };
} 