# Tests for VSCode settings JSON content
#
# Verifies that mkVSCodeSettings produces correct JSON with the right keys,
# engine references, and that overrides work correctly. Pure eval only.
#
# NOTE: mkVSCodeSettings returns a JSON string with store path context.
# We use builtins.unsafeDiscardStringContext to strip the context so Nix
# doesn't try to realize the derivations in the sandbox.
{
  pkgs,
  lib,
  ...
}: let
  mkVSCodeModules = engine: let
    documentProcessing = import ../modules/latex-utils/document-processing.nix {
      inherit pkgs lib;
      documents = [];
      moduleExtraTexPackages = [];
      inherit engine;
    };
    texEnvironment = import ../modules/latex-utils/tex-environment.nix {
      inherit pkgs lib;
      inherit (documentProcessing) unifiedAdditionalPackages;
      inherit engine;
    };
    vscodeIntegration = import ../modules/latex-utils/vscode-integration.nix {
      inherit pkgs lib;
      documents = [];
      moduleExtraTexPackages = [];
      inherit (texEnvironment) unifiedTexEnv ltexLsWrapped unifiedTexShell latexmkWrapper;
      inherit engine;
    };
  in vscodeIntegration;

  vscodeDefault = mkVSCodeModules "lualatex";
  vscodeXelatex = mkVSCodeModules "xelatex";

  # Strip store path context so sandbox doesn't force realization
  stripContext = builtins.unsafeDiscardStringContext;

  defaultJson = stripContext (vscodeDefault.mkVSCodeSettings {});
  xelatexJson = stripContext (vscodeXelatex.mkVSCodeSettings {});
in {
  # --- ltex settings ---

  testVSCodeSettingsContainsLtexLanguage = {
    expr = lib.hasInfix "\"ltex.language\":\"en-US\"" defaultJson;
    expected = true;
  };

  testVSCodeSettingsContainsLtexEnabled = {
    expr = lib.hasInfix "\"ltex.enabled\":true" defaultJson;
    expected = true;
  };

  testVSCodeSettingsContainsLtexServerPath = {
    expr = lib.hasInfix "\"ltex.server.path\":" defaultJson && lib.hasInfix "/bin/ltex-ls" defaultJson;
    expected = true;
  };

  # --- Tool configuration ---

  testVSCodeSettingsContainsLualatexToolName = {
    expr = lib.hasInfix "\"name\":\"latexmk-lualatex\"" defaultJson;
    expected = true;
  };

  testVSCodeSettingsContainsToolCommand = {
    expr = lib.hasInfix "\"command\":" defaultJson && lib.hasInfix "/bin/latexmk" defaultJson;
    expected = true;
  };

  testVSCodeSettingsContainsToolArgs = {
    expr = lib.hasInfix "\"args\":[\"%DOC%\"]" defaultJson;
    expected = true;
  };

  # --- Recipe configuration ---

  testVSCodeSettingsContainsLualatexRecipeName = {
    expr = lib.hasInfix "\"name\":\"latexmk (lualatex)\"" defaultJson;
    expected = true;
  };

  testVSCodeSettingsContainsRecipeTools = {
    expr = lib.hasInfix "\"tools\":[\"latexmk-lualatex\"]" defaultJson;
    expected = true;
  };

  testVSCodeSettingsContainsRecipeDefault = {
    expr = lib.hasInfix "\"latex-workshop.latex.recipe.default\":\"latexmk (lualatex)\"" defaultJson;
    expected = true;
  };

  # --- Build and output settings ---

  testVSCodeSettingsAutoBuildOnSave = {
    expr = lib.hasInfix "\"latex-workshop.latex.autoBuild.run\":\"onSave\"" defaultJson;
    expected = true;
  };

  testVSCodeSettingsOutDir = {
    expr = lib.hasInfix "\"latex-workshop.latex.outDir\":\".latex-build\"" defaultJson;
    expected = true;
  };

  testVSCodeSettingsPdfViewer = {
    expr = lib.hasInfix "\"latex-workshop.view.pdf.viewer\":\"tab\"" defaultJson;
    expected = true;
  };

  testVSCodeSettingsAutoClean = {
    expr = lib.hasInfix "\"latex-workshop.latex.autoClean.run\":\"onBuilt\"" defaultJson;
    expected = true;
  };

  # --- Clean file types ---

  testVSCodeSettingsContainsAuxCleanup = {
    expr = lib.hasInfix "\"*.aux\"" defaultJson;
    expected = true;
  };

  testVSCodeSettingsContainsLogCleanup = {
    expr = lib.hasInfix "\"*.log\"" defaultJson;
    expected = true;
  };

  testVSCodeSettingsContainsSynctexCleanup = {
    expr = lib.hasInfix "\"*.synctex.gz\"" defaultJson;
    expected = true;
  };

  # --- Synctex settings ---

  testVSCodeSettingsSynctexAfterBuildDisabled = {
    expr = lib.hasInfix "\"latex-workshop.synctex.afterBuild.enabled\":false" defaultJson;
    expected = true;
  };

  testVSCodeSettingsPdfInternalSynctex = {
    expr = lib.hasInfix "\"latex-workshop.view.pdf.internal.synctex.keybinding\":\"double-click\"" defaultJson;
    expected = true;
  };

  # --- Engine-specific settings ---

  testXelatexSettingsContainsToolName = {
    expr = lib.hasInfix "\"name\":\"latexmk-xelatex\"" xelatexJson;
    expected = true;
  };

  testXelatexSettingsContainsRecipeName = {
    expr = lib.hasInfix "\"name\":\"latexmk (xelatex)\"" xelatexJson;
    expected = true;
  };

  testXelatexSettingsContainsRecipeDefault = {
    expr = lib.hasInfix "\"latex-workshop.latex.recipe.default\":\"latexmk (xelatex)\"" xelatexJson;
    expected = true;
  };

  testXelatexSettingsDoesNotContainLualatex = {
    expr = lib.hasInfix "lualatex" xelatexJson;
    expected = false;
  };

  # --- Override function ---

  testVSCodeSettingsOverrideAutoBuild = {
    expr = let
      overrideJson = stripContext (vscodeDefault.mkVSCodeSettings {
        "latex-workshop.latex.autoBuild.run" = "onFileChange";
      });
    in
      lib.hasInfix "\"latex-workshop.latex.autoBuild.run\":\"onFileChange\"" overrideJson
      && !(lib.hasInfix "\"latex-workshop.latex.autoBuild.run\":\"onSave\"" overrideJson);
    expected = true;
  };

  testVSCodeSettingsAddCustomKey = {
    expr = let
      overrideJson = stripContext (vscodeDefault.mkVSCodeSettings {
        "custom-key" = "custom-value";
      });
    in lib.hasInfix "\"custom-key\":\"custom-value\"" overrideJson;
    expected = true;
  };

  testVSCodeSettingsOverridePreservesExisting = {
    expr = let
      overrideJson = stripContext (vscodeDefault.mkVSCodeSettings {
        "custom-key" = "custom-value";
      });
    in
      lib.hasInfix "\"ltex.language\":\"en-US\"" overrideJson
      && lib.hasInfix "\"custom-key\":\"custom-value\"" overrideJson;
    expected = true;
  };
}
