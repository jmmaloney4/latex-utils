{
  pkgs,
  lib,
  ...
}: let
  # Keep documents empty here to focus on engine wiring without filesystem access
  documents = [];
  moduleExtraTexPackages = [];
  engine = "xelatex";

  documentProcessing = import ../modules/latex-utils/document-processing.nix {
    inherit pkgs lib documents moduleExtraTexPackages;
    inherit engine;
  };

  texEnvironment = import ../modules/latex-utils/tex-environment.nix {
    inherit pkgs lib engine;
    inherit (documentProcessing) unifiedAdditionalPackages;
  };

  vscodeIntegration = import ../modules/latex-utils/vscode-integration.nix {
    inherit pkgs lib documents moduleExtraTexPackages engine;
    inherit (texEnvironment) unifiedTexEnv ltexLsWrapped unifiedTexShell latexmkWrapper;
  };

  latexmkPackage = texEnvironment.unifiedPackages.latexmk;
  vscodeRecipesPackage = vscodeIntegration.vscodeRecipesPackage;

  # Shared test helpers
  testHelpers = import ../lib/testHelpers.nix {inherit pkgs lib;};
  inherit (testHelpers) builds;
in {
  # Package derivations exist
  testLatexmkWrapperPackageExists = {
    expr = lib.isDerivation latexmkPackage;
    expected = true;
  };

  testVscodeRecipesPackageExists = {
    expr = lib.isDerivation vscodeRecipesPackage;
    expected = true;
  };

  # Buildability
  testLatexmkWrapperBuilds = {
    expr = builds latexmkPackage;
    expected = true;
  };

  testVscodeRecipesBuilds = {
    expr = builds vscodeRecipesPackage;
    expected = true;
  };

  # Wrapper configuration contains the requested engine and output directory
  testLatexmkWrapperContainsEngineDefaults = {
    expr = builds (pkgs.runCommand "latexmk-wrapper-check" {} ''
      set -euo pipefail
      grep -q 'xelatex' "${latexmkPackage}/bin/latexmk"
      grep -q -- '-output-directory=.latex-build' "${latexmkPackage}/bin/latexmk"
      touch "$out"
    '');
    expected = true;
  };
}
