{
  config,
  lib,
  flake-parts-lib,
  ...
}: let
  # Import type definitions
  types = import ./latex-utils/types.nix {inherit lib;};

  # Import option definitions
  optionsModule = import ./latex-utils/options.nix {
    inherit lib flake-parts-lib;
    inherit types;
  };

  # Get module-level configuration
  documents = config.latex-utils.documents;
  moduleExtraTexPackages = config.latex-utils.extraTexPackages;
  enableVSCode = config.latex-utils.enableVSCode;
  flakeCheck = config.latex-utils.flakeCheck;
  engine = config.latex-utils.latexmk.engine or "lualatex";
in {
  # Import options from the options module
  inherit (optionsModule) options;

  config = {
    # Register transposition for latex-utils namespace
    # This makes outputs.latex-utils.${system}.* available externally
    transposition.latex-utils = {};

    perSystem = {
      config,
      pkgs,
      lib,
      inputs',
      system,
      ...
    }: let
      # Import document processing logic
      documentProcessing = import ./latex-utils/document-processing.nix {
        inherit pkgs lib documents moduleExtraTexPackages;
        engine = engine;
      };

      # Import TeX environment creation
      texEnvironment = import ./latex-utils/tex-environment.nix {
        inherit pkgs lib;
        inherit (documentProcessing) unifiedAdditionalPackages;
        engine = engine;
      };

      # Import VSCode integration
      vscodeIntegration = import ./latex-utils/vscode-integration.nix {
        inherit pkgs lib documents moduleExtraTexPackages;
        inherit (texEnvironment) unifiedTexEnv ltexLsWrapped unifiedTexShell latexmkWrapper;
        engine = engine;
      };

      # Import output assembly
      outputsModule = import ./latex-utils/outputs.nix {
        inherit config lib pkgs documents enableVSCode flakeCheck;
        # Document processing outputs
        inherit (documentProcessing) mkDoc;
        # TeX environment outputs
        inherit (texEnvironment) unifiedPackages unifiedTexShell;
        # VSCode integration outputs
        inherit (vscodeIntegration) vscodeIntegration latexUtilsVSCodeFragment vscodeSettingsCustomApp vscodeRecipesPackage;
      };
    in
      lib.mkMerge [outputsModule];
  };
}
