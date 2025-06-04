{
  pkgs,
  lib,
  unifiedTexEnv,
  ltexLsWrapped,
  unifiedTexShell,
  documents,
  moduleExtraTexPackages,
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
          command = "${unifiedTexEnv}/bin/latexmk";
          args = [
            # Core compilation options
            "-pdf" # Generate PDF output
            "-interaction=nonstopmode" # Don't stop on errors (good for IDE)
            "-file-line-error" # Error format: file:line:error (IDE-friendly)
            "-synctex=1" # Enable SyncTeX for editor-PDF sync

            # Build organization
            "-output-directory=.latex-build" # Put ALL build artifacts in .latex-build/

            # Enhanced IDE experience
            "-recorder" # Create .fls file for dependency tracking
            "-silent" # Quieter output (less noise in IDE)
            "-bibtex" # Ensure bibliography processing

            # Document placeholder
            "%DOC%"
          ];
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
    buildInputs = [unifiedTexEnv ltexLsWrapped];
    shellHook = ''
      echo "🔧 Setting up VSCode LaTeX integration..."
      mkdir -p .vscode
      ln -sf "${vscodeSettings}/.vscode/settings.json" .vscode/settings.json
      echo "✅ VSCode settings linked successfully!"
      echo "📦 Using unified TeX Live environment with packages from:"
      ${docCountMsg}${modulePkgMsg}
    '';
  };

  # VS Code settings shell fragment (composable)
  latexUtilsVSCodeFragment = pkgs.mkShell {
    name = "latex-utils-vscode-fragment";
    inputsFrom = [unifiedTexShell]; # Ensures unifiedTexShell environment is included
    shellHook = ''
      mkdir -p .vscode
      ln -sf "${vscodeSettings}/.vscode/settings.json" .vscode/settings.json
      echo "VS Code settings linked (composable fragment)."
    '';
  };

  # VSCode integration packages (only include derivations)
  vscodeIntegration = {
    vscode-settings = vscodeSettings;
    vscode-devshell = vscodeDevShell;
    ltex-ls-wrapped = ltexLsWrapped;
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
    ;
}
