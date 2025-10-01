{
  pkgs,
  lib,
  unifiedTexEnv,
  ltexLsWrapped,
  unifiedTexShell,
  latexmkWrapper,
  documents,
  moduleExtraTexPackages,
  engine ? "lualatex",
}: let
  # Function to generate VSCode settings with custom overrides
  mkVSCodeSettings = overrides: let
    defaultSettings = {
      "ltex.language" = "en-US";
      "ltex.enabled" = true;
      "ltex.server.path" = "${ltexLsWrapped}/bin/ltex-ls";

      # LaTeX Workshop configuration using unified environment
      "latex-workshop.latex.toolchain" = [
        {
          command = "${latexmkWrapper}/bin/latexmk";
          args = ["%DOC%"];
        }
      ];

      # Auto-build configuration
      "latex-workshop.latex.autoBuild.run" = "onFileChange";

      # Output and cleanup configuration
      "latex-workshop.latex.outDir" = ".latex-build";
      "latex-workshop.latex.autoClean.run" = "onBuilt";
      "latex-workshop.latex.clean.fileTypes" = [
        "*.aux"
        "*.bbl"
        "*.blg"
        "*.idx"
        "*.ind"
        "*.lof"
        "*.lot"
        "*.out"
        "*.toc"
        "*.acn"
        "*.acr"
        "*.alg"
        "*.glg"
        "*.glo"
        "*.gls"
        "*.ist"
        "*.fls"
        "*.log"
        "*.fdb_latexmk"
        "*.synctex.gz"
      ];

      # PDF viewer configuration
      "latex-workshop.view.pdf.viewer" = "tab";
      "latex-workshop.view.pdf.internal.synctex.keybinding" = "double-click";

      # Forward search configuration (editor -> PDF)
      "latex-workshop.synctex.afterBuild.enabled" = true;
    };
    settings = defaultSettings // overrides;
  in
    builtins.toJSON settings;

  # Default VSCode settings package
  vscodeSettings = pkgs.writeTextFile {
    name = "vscode-settings";
    destination = "/.vscode/settings.json";
    text = mkVSCodeSettings {};
  };

  # VSCode settings function for custom overrides
  vscodeSettingsWithOverrides = overrides:
    pkgs.writeTextFile {
      name = "vscode-settings-custom";
      destination = "/.vscode/settings.json";
      text = mkVSCodeSettings overrides;
    };

  # Generate LaTeX Workshop recipes JSON aligned with engine
  vscodeRecipesJson = builtins.toJSON {
    "latex-workshop.latex.recipes" = [
      {
        name = "latexmk (${engine})";
        tools = ["latexmk-${engine}"];
      }
    ];
    "latex-workshop.latex.tools" = [
      {
        name = "latexmk-${engine}";
        command = "${latexmkWrapper}/bin/latexmk";
        args = ["%DOC%"];
        env = [];
      }
    ];
  };

  vscodeRecipesPackage = pkgs.writeTextFile {
    name = "vscode-latex-workshop-recipes";
    destination = "/.vscode/settings.json";
    text = vscodeRecipesJson;
  };

  # Common helper function for VSCode setup shellHook
  mkVSCodeSetupShellHook = {
    extraMessage ? "",
    showDetailedInfo ? false,
  }: ''
    mkdir -p .vscode
    ln -sf "${vscodeSettings}/.vscode/settings.json" .vscode/settings.json
    ${
      if showDetailedInfo
      then ''
        if [ -z "''${LATEX_UTILS_VSCODE_READY:-}" ]; then
          export LATEX_UTILS_VSCODE_READY=1
          echo "🔧 Setting up VSCode LaTeX integration..."
          echo "✅ VSCode settings linked successfully!"
          echo "📦 Using unified TeX Live environment with packages from:"
          ${docCountMsg}${modulePkgMsg}
        fi
      ''
      else ''
        if [ -z "''${LATEX_UTILS_VSCODE_READY:-}" ]; then
          export LATEX_UTILS_VSCODE_READY=1
          echo "VS Code settings linked${
          if extraMessage != ""
          then " (${extraMessage})"
          else ""
        }."
        fi
      ''
    }
  '';

  # Helper strings for shellHook conditional messages
  docCountMsg =
    if documents != []
    then
      (''
          echo "   - ${toString (builtins.length documents)} configured document(s)"
        ''
        + "\n")
    else "";

  modulePkgMsg =
    if moduleExtraTexPackages != []
    then
      (''
          echo "   - Module-level extraTexPackages"
        ''
        + "\n")
    else "";

  # Helper dev shell that sets up VSCode integration
  vscodeDevShell = pkgs.mkShell {
    buildInputs = [latexmkWrapper unifiedTexEnv ltexLsWrapped];
    shellHook = mkVSCodeSetupShellHook {showDetailedInfo = true;};
  };

  # VS Code settings shell fragment (composable)
  latexUtilsVSCodeFragment = pkgs.mkShell {
    name = "latex-utils-vscode-fragment";
    inputsFrom = [unifiedTexShell]; # Ensures unifiedTexShell environment is included
    shellHook = mkVSCodeSetupShellHook {extraMessage = "composable fragment";};
  };

  # VSCode integration packages (only include derivations)
  vscodeIntegration = {
    vscodeSettings = vscodeSettings;
    vscodeRecipes = vscodeRecipesPackage;
    vscodeShell = vscodeDevShell;
    ltex-ls = ltexLsWrapped;
  };

  # Application for generating custom VSCode settings
  vscodeSettingsCustomApp = {
    type = "app";
    program = "${pkgs.writeShellScript "vscode-settings-custom" ''
      ${lib.getExe pkgs.jq} -n "$1" > settings.json
      echo "Generated VSCode settings in settings.json"
    ''}";
    meta.description = "Generate custom VSCode settings for LaTeX with your overrides";
  };
in {
  inherit
    mkVSCodeSettings
    vscodeSettings
    vscodeSettingsWithOverrides
    vscodeDevShell
    latexUtilsVSCodeFragment
    vscodeIntegration
    vscodeSettingsCustomApp
    vscodeRecipesPackage
    ;
}
