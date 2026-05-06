# Tests for VSCode settings JSON content
#
# Verifies that mkVSCodeSettings produces correct JSON with the right keys,
# engine references, and that overrides work correctly. Pure eval only.
#
# mkVSCodeSettings returns a JSON string with store path context. We use
# builtins.unsafeDiscardStringContext to strip the context, then parse with
# builtins.fromJSON for structural validation (more robust than string matching).
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

  # Strip store path context so sandbox doesn't force realization,
  # then parse JSON for structural access
  parseSettings = settings: builtins.fromJSON (builtins.unsafeDiscardStringContext settings);

  defaultSettings = parseSettings (vscodeDefault.mkVSCodeSettings {});
  xelatexSettings = parseSettings (vscodeXelatex.mkVSCodeSettings {});

  # Helpers -- VSCode settings use flat dotted keys (not nested objects)
  tools = settings: settings."latex-workshop.latex.tools";
  recipes = settings: settings."latex-workshop.latex.recipes";
in {
  # --- ltex settings ---

  testVSCodeSettingsContainsLtexLanguage = {
    expr = defaultSettings."ltex.language";
    expected = "en-US";
  };

  testVSCodeSettingsContainsLtexEnabled = {
    expr = defaultSettings."ltex.enabled";
    expected = true;
  };

  testVSCodeSettingsContainsLtexServerPath = {
    expr = lib.hasInfix "/bin/ltex-ls" defaultSettings."ltex.server.path";
    expected = true;
  };

  # --- Tool configuration ---

  testVSCodeSettingsContainsLualatexToolName = {
    expr = (builtins.head (tools defaultSettings)).name;
    expected = "latexmk-lualatex";
  };

  testVSCodeSettingsContainsToolCommand = {
    expr = lib.hasInfix "/bin/latexmk" (builtins.head (tools defaultSettings)).command;
    expected = true;
  };

  testVSCodeSettingsContainsToolArgs = {
    expr = (builtins.head (tools defaultSettings)).args;
    expected = ["%DOC%"];
  };

  # --- Recipe configuration ---

  testVSCodeSettingsContainsLualatexRecipeName = {
    expr = (builtins.head (recipes defaultSettings)).name;
    expected = "latexmk (lualatex)";
  };

  testVSCodeSettingsContainsRecipeTools = {
    expr = (builtins.head (recipes defaultSettings)).tools;
    expected = ["latexmk-lualatex"];
  };

  testVSCodeSettingsContainsRecipeDefault = {
    expr = defaultSettings."latex-workshop.latex.recipe.default";
    expected = "latexmk (lualatex)";
  };

  # --- Build and output settings ---

  testVSCodeSettingsAutoBuildOnSave = {
    expr = defaultSettings."latex-workshop.latex.autoBuild.run";
    expected = "onSave";
  };

  testVSCodeSettingsOutDir = {
    expr = defaultSettings."latex-workshop.latex.outDir";
    expected = ".latex-build";
  };

  testVSCodeSettingsPdfViewer = {
    expr = defaultSettings."latex-workshop.view.pdf.viewer";
    expected = "tab";
  };

  testVSCodeSettingsAutoClean = {
    expr = defaultSettings."latex-workshop.latex.autoClean.run";
    expected = "onBuilt";
  };

  # --- Clean file types ---

  testVSCodeSettingsContainsAuxCleanup = {
    expr = builtins.elem "*.aux" defaultSettings."latex-workshop.latex.clean.fileTypes";
    expected = true;
  };

  testVSCodeSettingsContainsLogCleanup = {
    expr = builtins.elem "*.log" defaultSettings."latex-workshop.latex.clean.fileTypes";
    expected = true;
  };

  testVSCodeSettingsContainsSynctexCleanup = {
    expr = builtins.elem "*.synctex.gz" defaultSettings."latex-workshop.latex.clean.fileTypes";
    expected = true;
  };

  # --- Synctex settings ---

  testVSCodeSettingsSynctexAfterBuildDisabled = {
    expr = defaultSettings."latex-workshop.synctex.afterBuild.enabled";
    expected = false;
  };

  testVSCodeSettingsPdfInternalSynctex = {
    expr = defaultSettings."latex-workshop.view.pdf.internal.synctex.keybinding";
    expected = "double-click";
  };

  # --- Engine-specific settings ---

  testXelatexSettingsContainsToolName = {
    expr = (builtins.head (tools xelatexSettings)).name;
    expected = "latexmk-xelatex";
  };

  testXelatexSettingsContainsRecipeName = {
    expr = (builtins.head (recipes xelatexSettings)).name;
    expected = "latexmk (xelatex)";
  };

  testXelatexSettingsContainsRecipeDefault = {
    expr = xelatexSettings."latex-workshop.latex.recipe.default";
    expected = "latexmk (xelatex)";
  };

  testXelatexSettingsDoesNotContainLualatex = {
    expr =
      !(lib.hasInfix "lualatex" ((builtins.head (tools xelatexSettings)).name or ""))
      && !(lib.hasInfix "lualatex" ((builtins.head (recipes xelatexSettings)).name or ""));
    expected = true;
  };

  # --- Override function ---

  testVSCodeSettingsOverrideAutoBuild = {
    expr = let
      overrideSettings = parseSettings (vscodeDefault.mkVSCodeSettings {
        "latex-workshop.latex.autoBuild.run" = "onFileChange";
      });
    in overrideSettings."latex-workshop.latex.autoBuild.run";
    expected = "onFileChange";
  };

  testVSCodeSettingsAddCustomKey = {
    expr = let
      overrideSettings = parseSettings (vscodeDefault.mkVSCodeSettings {
        "custom-key" = "custom-value";
      });
    in overrideSettings."custom-key" or null;
    expected = "custom-value";
  };

  testVSCodeSettingsOverridePreservesExisting = {
    expr = let
      overrideSettings = parseSettings (vscodeDefault.mkVSCodeSettings {
        "custom-key" = "custom-value";
      });
    in {
      hasLtex = overrideSettings."ltex.language" or null == "en-US";
      hasCustom = overrideSettings."custom-key" or null == "custom-value";
    };
    expected = {hasLtex = true; hasCustom = true;};
  };
}
