# Tests for module-level options: flakeCheck, enableVSCode, engine, documentsPackage
#
# These tests import submodules directly (no flake harness) and verify option wiring
# without building any derivations. Pure eval only.
{
  pkgs,
  lib,
  ...
}: let
  types = import ../modules/latex-utils/types.nix {inherit lib;};
  optionsModule = import ../modules/latex-utils/options.nix {
    inherit lib types;
    flake-parts-lib = {
      mkPerSystemOption = x: x;
    };
  };

  evalLatexUtils = module:
    lib.evalModules {
      modules = [
        optionsModule
        module
      ];
    };

  # Import the three submodules with the given configuration
  mkModuleOutputs = {
    documents ? [],
    moduleExtraTexPackages ? [],
    moduleCommonAdditionalSources ? [],
    engine ? "lualatex",
  }: let
    documentProcessing = import ../modules/latex-utils/document-processing.nix {
      inherit pkgs lib documents moduleExtraTexPackages moduleCommonAdditionalSources engine;
    };

    texEnvironment = import ../modules/latex-utils/tex-environment.nix {
      inherit pkgs lib engine;
      inherit (documentProcessing) unifiedAdditionalPackages;
    };

    vscodeIntegration = import ../modules/latex-utils/vscode-integration.nix {
      inherit pkgs lib documents moduleExtraTexPackages engine;
      inherit (texEnvironment) unifiedTexEnv ltexLsWrapped unifiedTexShell latexmkWrapper;
    };
  in {
    inherit documentProcessing texEnvironment vscodeIntegration;
  };

  # Default config (empty documents, no extra packages, lualatex)
  defaultOutputs = mkModuleOutputs {};

  # Fake mkDoc that doesn't try to build anything
  fakeMkDoc = doc: pkgs.runCommand "${doc.name}" {} "echo ${doc.name} > $out";

  # Call outputs.nix with a fake config that provides config.latex-utils.vscodeShell
  mkOutputs = {
    documents ? [],
    enableVSCode ? true,
    flakeCheck ? false,
  }: let
    mods = mkModuleOutputs {inherit documents;};
    fakeConfig = {
      latex-utils = {
        vscodeShell = mods.vscodeIntegration.latexUtilsVSCodeFragment;
      };
    };
  in
    import ../modules/latex-utils/outputs.nix {
      config = fakeConfig;
      inherit lib pkgs documents enableVSCode flakeCheck;
      mkDoc = fakeMkDoc;
      unifiedPackages = mods.texEnvironment.unifiedPackages;
      unifiedTexShell = mods.texEnvironment.unifiedTexShell;
      vscodeIntegration = mods.vscodeIntegration.vscodeIntegration;
      latexUtilsVSCodeFragment = mods.vscodeIntegration.latexUtilsVSCodeFragment;
      vscodeSettingsCustomApp = mods.vscodeIntegration.vscodeSettingsCustomApp;
    };

  # Outputs with default config
  defaultOut = mkOutputs {};

  # Outputs with flakeCheck enabled
  flakeCheckOut = mkOutputs {flakeCheck = true;};

  # Outputs with VSCode disabled
  noVSCodeOut = mkOutputs {enableVSCode = false;};

  # Outputs with one document
  oneDocOut = mkOutputs {
    documents = [
      {
        name = "thesis.pdf";
        src = ./..;
      }
    ];
  };

  # Outputs with two documents
  twoDocOut = mkOutputs {
    documents = [
      {
        name = "first.pdf";
        src = ./..;
      }
      {
        name = "second.pdf";
        src = ./..;
      }
    ];
  };

  moduleSharedSource = pkgs.writeTextDir "module-shared/templates/cavinslegal.cls" ''
    \NeedsTeXFormat{LaTeX2e}
  '';

  documentSharedSource = pkgs.writeTextDir "document-shared/bib/shared/shared.bib" ''
    @book{shared, title = {Shared Source}}
  '';

  docWithComposedSources = {
    name = "shared.pdf";
    src = ./..;
    additionalSources = [documentSharedSource];
  };

  composedSourceOutputs = mkModuleOutputs {
    documents = [docWithComposedSources];
    moduleCommonAdditionalSources = [moduleSharedSource];
  };

  composedSourceDrv = composedSourceOutputs.documentProcessing.mkDoc docWithComposedSources;
in {
  # --- flakeCheck option ---

  testFlakeCheckDefaultDisabled = {
    expr = defaultOut.checks or {};
    expected = {};
  };

  testFlakeCheckEnabledProducesCheck = {
    expr = builtins.hasAttr "latex" flakeCheckOut.checks;
    expected = true;
  };

  testFlakeCheckProducedIsDerivation = {
    expr = lib.isDerivation flakeCheckOut.checks.latex;
    expected = true;
  };

  # --- enableVSCode option ---

  testEnableVSCodeTrueProducesDevShell = {
    expr =
      defaultOut.devShells ? "latex-utils"
      && lib.isDerivation defaultOut.devShells."latex-utils";
    expected = true;
  };

  testEnableVSCodeFalseSkipsDevShell = {
    expr = noVSCodeOut.devShells or {};
    expected = {};
  };

  # --- documentsPackage aggregation ---

  testDocumentsPackageSkippedWhenEmpty = {
    expr = defaultOut.packages ? "documents";
    expected = false;
  };

  testDocumentsPackagePresentWhenDocsExist = {
    expr =
      oneDocOut.packages ? "documents"
      && lib.isDerivation oneDocOut.packages.documents;
    expected = true;
  };

  testDefaultPackageIsFirstDocument = {
    expr = twoDocOut.packages.default.name or "";
    expected = "first.pdf";
  };

  testPerDocumentPackagesExist = {
    expr =
      twoDocOut.packages ? "first"
      && twoDocOut.packages ? "second"
      && lib.isDerivation twoDocOut.packages.first
      && lib.isDerivation twoDocOut.packages.second;
    expected = true;
  };

  # --- apps output ---

  testAppsIncludeVSCodeSettingsCustom = {
    expr =
      defaultOut.apps ? "vscode-settings-custom"
      && defaultOut.apps.vscode-settings-custom.type or "" == "app";
    expected = true;
  };

  # --- latex-utils config output (per-system) ---

  testLatexUtilsConfigHasUnifiedTexShell = {
    expr =
      defaultOut.latex-utils ? "unifiedTexShell"
      && lib.isDerivation defaultOut.latex-utils.unifiedTexShell;
    expected = true;
  };

  testLatexUtilsConfigHasVscodeShell = {
    expr =
      defaultOut.latex-utils ? "vscodeShell"
      && lib.isDerivation defaultOut.latex-utils.vscodeShell;
    expected = true;
  };

  # --- unifiedPackages always present ---

  testUnifiedPackagesPresentWithoutDocs = {
    expr =
      defaultOut.packages ? "texlive"
      && defaultOut.packages ? "latexmk"
      && defaultOut.packages ? "latexindent";
    expected = true;
  };

  # --- engine wiring (verify wrapper script text contains engine flag) ---
  # NOTE: We use .text on the derivation to read the script content without
  # forcing realization (builtins.readFile would fail in the Nix sandbox).

  testXelatexEnginePropagatesToWrapper = let
    xelatexOutputs = mkModuleOutputs {engine = "xelatex";};
    wrapper = xelatexOutputs.texEnvironment.latexmkWrapper;
  in {
    expr = lib.hasInfix "xelatex" wrapper.text;
    expected = true;
  };

  testPdflatexEnginePropagatesToWrapper = let
    pdflatexOutputs = mkModuleOutputs {engine = "pdflatex";};
    wrapper = pdflatexOutputs.texEnvironment.latexmkWrapper;
  in {
    expr = lib.hasInfix "pdflatex" wrapper.text;
    expected = true;
  };

  testDocumentAdditionalSourcesStructure = {
    expr = let
      evaluated = evalLatexUtils {
        latex-utils.documents = [
          {
            name = "mydoc.pdf";
            src = ./..;
            additionalSources = [./tests];
          }
        ];
      };
    in
      (builtins.head evaluated.config.latex-utils.documents).additionalSources == [./tests];
    expected = true;
  };

  testModuleCommonAdditionalSourcesStructure = {
    expr =
      (evalLatexUtils {
        latex-utils = {
          commonAdditionalSources = [./..];
          documents = [];
        };
      }).config.latex-utils.commonAdditionalSources
      == [./..];
    expected = true;
  };

  testDocumentAdditionalSourcesDefaultFromModule = {
    expr = let
      evaluated = evalLatexUtils {
        latex-utils.documents = [
          {
            name = "mydoc.pdf";
            src = ./..;
          }
        ];
      };
    in
      (builtins.head evaluated.config.latex-utils.documents).additionalSources == [];
    expected = true;
  };

  testCommonAndDocumentAdditionalSourcesPropagateToBuild = {
    expr = let
      buildPhaseParts = lib.splitString "${documentSharedSource}" composedSourceDrv.buildPhase;
    in
      lib.hasInfix "${moduleSharedSource}" composedSourceDrv.buildPhase
      && lib.hasInfix "${documentSharedSource}" composedSourceDrv.buildPhase
      && builtins.length buildPhaseParts > 1
      && lib.hasInfix "${moduleSharedSource}" (builtins.elemAt buildPhaseParts 1);
    expected = true;
  };
}
