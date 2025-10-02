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
  vscodeSettingsPackage = vscodeIntegration.vscodeSettings;

  # Shared test helpers
  testHelpers = import ../lib/testHelpers.nix {inherit pkgs lib;};
  inherit (testHelpers) builds;
in {
  # Package derivations exist
  testLatexmkWrapperPackageExists = {
    expr = lib.isDerivation latexmkPackage;
    expected = true;
  };

  testVscodeSettingsPackageExists = {
    expr = lib.isDerivation vscodeSettingsPackage;
    expected = true;
  };

  # Buildability
  testLatexmkWrapperBuilds = {
    expr = builds latexmkPackage;
    expected = true;
  };

  testVscodeSettingsPackageBuilds = {
    expr = builds vscodeSettingsPackage;
    expected = true;
  };

  testVscodeSettingsContainsRecipeDefaults = {
    expr = builds (pkgs.runCommand "vscode-settings-check" {buildInputs = [pkgs.jq];} ''
      set -euo pipefail
      settings_file="${vscodeSettingsPackage}/.vscode/settings.json"
      jq --exit-status '
        (."latex-workshop.latex.recipe.default" == "latexmk (xelatex)")
        and ((."latex-workshop.latex.recipes" | length) == 1)
        and ((."latex-workshop.latex.recipes"[0] | .name == "latexmk (xelatex)" and .tools == ["latexmk-xelatex"]))
        and ((."latex-workshop.latex.tools" | length) == 1)
        and ((."latex-workshop.latex.tools"[0] | .name == "latexmk-xelatex" and (.command | endswith("/bin/latexmk"))))
      ' "$settings_file" >/dev/null
      touch "$out"
    '');
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
