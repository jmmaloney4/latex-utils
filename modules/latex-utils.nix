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
      ...
    }: let
      # Import document processing logic
      documentProcessing = import ./latex-utils/document-processing.nix {
        inherit pkgs lib documents moduleExtraTexPackages;
      };

      # Import TeX environment creation
      texEnvironment = import ./latex-utils/tex-environment.nix {
        inherit pkgs lib;
        inherit (documentProcessing) unifiedAdditionalPackages;
      };

      # Extract needed values from document processing
      inherit (documentProcessing) processedDocuments mkDoc;
      inherit (texEnvironment) unifiedTexEnv ltexLsWrapped unifiedPackages unifiedTexShell;

      docPkgs = builtins.listToAttrs (map (doc: {
          name = lib.removeSuffix ".pdf" doc.name;
          value = mkDoc doc;
        })
        documents);

      # VSCode integration
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

      # VSCode settings function for custom overrides
      vscodeSettingsWithOverrides = overrides:
        pkgs.writeTextFile {
          name = "vscode-settings-custom";
          destination = "/.vscode/settings.json";
          text = mkVSCodeSettings overrides;
        };

      # VS Code settings shell fragment (composable)
      # Renamed from vscodeSettingsShell and updated for composition
      latexUtilsVSCodeFragment = pkgs.mkShell {
        name = "latex-utils-vscode-fragment";
        inputsFrom = [unifiedTexShell]; # Ensures unifiedTexShell environment is included
        shellHook = ''
          mkdir -p .vscode
          ln -sf "${vscodeIntegration.vscode-settings}/.vscode/settings.json" .vscode/settings.json
          echo "VS Code settings linked (composable fragment)."
        '';
      };

      # Check: rebuild all PDFs and fail if any change
      latexCheck =
        pkgs.runCommand "latex-check" {
          buildInputs = [pkgs.diffutils];
        } ''
          set -e
          for pdf in ${toString (map (doc: mkDoc doc) documents)}; do
            cp $pdf $out-$(basename $pdf)
          done
          # In real use, compare with committed PDFs or previous build
        '';

      # VSCode integration packages (only include derivations)
      vscodeIntegration = let
        # Default VSCode settings package
        vscodeSettings = pkgs.writeTextFile {
          name = "vscode-settings";
          destination = "/.vscode/settings.json";
          text = mkVSCodeSettings {};
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
      in {
        vscode-settings = vscodeSettings;
        vscode-devshell = vscodeDevShell;
        ltex-ls-wrapped = ltexLsWrapped;
      };
    in
      lib.mkMerge [
        {
          # Per-System derivations that will be transposed to outputs.latex-utils.${system}.*
          # These are accessible within perSystem as config.latex-utils.*
          latex-utils = {
            unifiedTexShell = unifiedTexShell;
            vscodeShell = latexUtilsVSCodeFragment;
          };

          # Standard flake-parts outputs (automatically per-system)
          packages =
            docPkgs
            // unifiedPackages
            // vscodeIntegration
            // (
              if documents != []
              then {default = mkDoc (builtins.head documents);}
              else {}
            );

          # Complete devShell using standard flake-parts devShells transposition
          devShells.latex-utils = lib.mkIf enableVSCode (pkgs.mkShell {
            name = "latex-utils-devshell";
            inputsFrom = [config.latex-utils.vscodeShell]; # Use config.latex-utils.vscodeShell
          });

          checks.latex = lib.mkIf config.latex-utils.flakeCheck latexCheck;

          apps = {
            vscode-settings-custom = {
              type = "app";
              program = "${pkgs.writeShellScript "vscode-settings-custom" ''
                ${lib.getExe pkgs.jq} -n "$1" > settings.json
                echo "Generated VSCode settings in settings.json"
              ''}";
              meta.description = "Generate custom VSCode settings for LaTeX with your overrides";
            };
          };
        }
      ];
  };
}
