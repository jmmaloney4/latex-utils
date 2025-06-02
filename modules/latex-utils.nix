{
  config,
  lib,
  ...
}: let
  # Define custom types for extraTexPackages
  extraTexPackagesType =
    lib.types.either
    (lib.types.either
      (lib.types.listOf lib.types.str)
      (lib.types.listOf lib.types.package))
    (lib.types.functionTo (lib.types.listOf lib.types.package));

  docType = lib.types.submodule {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "Name of the output PDF/package";
        example = "my-paper.pdf";
      };
      src = lib.mkOption {
        type = lib.types.path;
        description = "Source directory for the LaTeX document";
        example = ./my-paper;
      };
      inputFile = lib.mkOption {
        type = lib.types.str;
        default = "main.tex";
        description = "Main .tex file (relative to src)";
        example = "main.tex";
      };
      workingDirectory = lib.mkOption {
        type = lib.types.str;
        default = ".";
        description = "Working directory within src for the LaTeX document";
        example = ".";
      };
      extraTexPackages = lib.mkOption {
        type = extraTexPackagesType;
        default = [];
        description = ''
          Extra TeX Live packages to include for this document.
          Can be:
          - List of package names (strings): ["mathrsfs" "xcolor"]
          - List of derivations: [pkgs.texlive.mathrsfs pkgs.myCustomTexPackage]
          - Function returning derivation list: (discovered: [pkgs.texlive.xcolor])

          Note: Lists must be homogeneous (all strings OR all derivations).
          Functions must return lists of derivations.

          See: https://nixos.wiki/wiki/TexLive#Customizing_TeX_Live_environments
        '';
        example = lib.literalExpression ''
          # List of package name strings
          ["mathrsfs" "xcolor"]

          # List of derivations
          [pkgs.texlive.mathrsfs pkgs.myCustomTexPackage]

          # Function (for dynamic package selection)
          (discovered: if builtins.hasAttr "tikz" discovered
                       then [pkgs.texlive.pgfplots]
                       else [])
        '';
      };
      # Add more mkLatexPdfDocument options as needed, with types and descriptions
    };
  };
  documents = config.latex-utils.documents;
  # perSystem logic will be injected below
in {
  options.latex-utils = {
    documents = lib.mkOption {
      type = lib.types.listOf docType;
      default = [];
      description = "List of LaTeX documents to build as packages";
    };
  };

  config = {
    perSystem = {
      config,
      pkgs,
      lib,
      ...
    }:
      lib.mkMerge [
        (let
          # Import helpers
          findLatexFiles = import ../lib/findLatexFiles.nix {inherit pkgs lib;};
          findLatexPackages = import ../lib/findLatexPackages.nix {inherit pkgs lib;};
          normalizeHelpers = import ../lib/normalizeExtraTexPackages.nix {inherit pkgs lib;};

          # Process each document to get its discovered and extra packages
          processedDocuments =
            map (doc: let
              # Get all LaTeX files for this document
              searchPaths = findLatexFiles {
                basePath = "${doc.src}/${doc.workingDirectory}";
              };
              # Extract packages from each file
              discovered =
                builtins.foldl' (a: b: a // b) {}
                (map (p:
                  if (builtins.pathExists p)
                  then findLatexPackages {fileContents = builtins.readFile p;}
                  else {})
                (lib.lists.unique searchPaths));

              # Normalize extraTexPackages using the helper
              extraNormalized = normalizeHelpers.normalizeExtraTexPackages {
                extraTexPackages = doc.extraTexPackages;
                discoveredPackages = discovered;
              };
            in {
              inherit doc discovered;
              extraNormalized = extraNormalized;
            })
            documents;

          # Collect all discovered packages from all documents
          allDiscoveredPackages =
            lib.lists.foldl (
              acc: processedDoc:
                acc // processedDoc.discovered
            ) {}
            processedDocuments;

          # Collect all extra packages from all documents
          allExtraPackagesAttrs =
            lib.lists.foldl (
              acc: processedDoc:
                acc // processedDoc.extraNormalized
            ) {}
            processedDocuments;

          # Combine discovered and extra packages (excluding base packages)
          unifiedAdditionalPackages = allDiscoveredPackages // allExtraPackagesAttrs;

          # Create unified TeX Live environment with all packages (including base packages)
          unifiedTexPackages =
            {
              inherit
                (pkgs.texlive)
                latex-bin
                latexmk
                biblatex
                biber
                csquotes
                luaotfload
                fontspec
                lm
                cm
                ec
                tex-gyre
                ;
              scheme = pkgs.texlive.scheme-basic;
            }
            // unifiedAdditionalPackages;

          unifiedTexEnv = pkgs.texlive.combine unifiedTexPackages;

          # Modified mkDoc function to pass normalized extraTexPackages
          mkDoc = doc: let
            processedDoc = lib.lists.findFirst (p: p.doc == doc) null processedDocuments;
            extraPackagesForDoc =
              if processedDoc != null
              then processedDoc.extraNormalized
              else {};
          in
            (pkgs.callPackage ../lib/mkLatexPdfDocument.nix {}) (doc
              // {
                # Pass the normalized extra packages specifically for this document
                extraTexPackages = extraPackagesForDoc;
                # Also pass unified additional packages for completeness
                texPackages = unifiedAdditionalPackages;
              });

          docPkgs = builtins.listToAttrs (map (doc: {
              name = lib.removeSuffix ".pdf" doc.name;
              value = mkDoc doc;
            })
            documents);

          # Create packages for the unified TeX Live environment and latexmk
          unifiedPackages = lib.optionalAttrs (documents != []) {
            texlive-unified = unifiedTexEnv;
            latexmk-unified = pkgs.writeShellScriptBin "latexmk" ''
              exec ${lib.getExe' unifiedTexEnv "latexmk"} "$@"
            '';
          };

          # VSCode integration
          vscodeIntegration = lib.optionalAttrs (documents != []) (let
            # Function to generate VSCode settings with custom overrides
            mkVSCodeSettings = overrides: let
              defaultSettings = {
                "ltex.language" = "en-US";
                "ltex.enabled" = true;
                "ltex.server.path" = "${pkgs.ltex-ls}/bin/ltex-ls";

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

            # Helper dev shell that sets up VSCode integration
            vscodeDevShell = pkgs.mkShell {
              buildInputs = [
                unifiedTexEnv
                pkgs.ltex-ls
              ];
              shellHook = ''
                echo "🔧 Setting up VSCode LaTeX integration..."
                mkdir -p .vscode
                ln -sf "${vscodeSettings}/.vscode/settings.json" .vscode/settings.json
                echo "✅ VSCode settings linked successfully!"
                echo "📦 Using unified TeX Live environment with all document packages"
              '';
            };
          in {
            vscode-settings = vscodeSettings;
            vscode-settings-with-overrides = vscodeSettingsWithOverrides;
            vscode-devshell = vscodeDevShell;
          });
        in {
          packages =
            if documents == []
            then {}
            else docPkgs // unifiedPackages // vscodeIntegration // {default = mkDoc (builtins.head documents);};

          devShells = lib.optionalAttrs (documents != []) {
            vscode = vscodeIntegration.vscode-devshell;
          };
        })
        # Other modules can extend perSystem here
      ];
  };
}
