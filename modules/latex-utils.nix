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
  moduleExtraTexPackages = config.latex-utils.extraTexPackages;
  # perSystem logic will be injected below
in {
  options.latex-utils = {
    documents = lib.mkOption {
      type = lib.types.listOf docType;
      default = [];
      description = "List of LaTeX documents to build as packages";
    };

    extraTexPackages = lib.mkOption {
      type = extraTexPackagesType;
      default = [];
      description = ''
        Extra TeX Live packages to include for ALL documents and environments.
        These packages are merged with document-specific packages.

        Can be:
        - List of package names (strings): ["mathrsfs" "xcolor"]
        - List of derivations: [pkgs.texlive.mathrsfs pkgs.myCustomTexPackage]
        - Function returning derivation list: (discovered: [pkgs.texlive.xcolor])

        Note: Lists must be homogeneous (all strings OR all derivations).
        Functions must return lists of derivations.
        Document-specific packages take precedence in case of conflicts.
      '';
      example = lib.literalExpression ''
        # Common packages for all documents
        ["amsmath" "amssymb" "mathtools" "unicode-math"]
      '';
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

          # First, normalize module-level extraTexPackages (once)
          # For module-level, we don't have discovered packages yet, so pass empty attrset
          moduleExtraPackagesNormalized = lib.addErrorContext "while normalizing module-level extraTexPackages" (
            normalizeHelpers.normalizeExtraTexPackages {
              extraTexPackages = moduleExtraTexPackages;
              discoveredPackages = {}; # No discovered packages at module level
            }
          );

          # Process each document to get its discovered and extra packages
          processedDocuments =
            map (doc: let
              # Get all LaTeX files for this document
              searchPaths = findLatexFiles {
                basePath = "${doc.src}/${doc.workingDirectory}";
              };

              # Extract packages from each file with better error handling
              discovered =
                builtins.foldl' (a: b: a // b) {}
                (map (p: let
                  pathStr = toString p;
                  contextMsg = "while discovering packages in ${pathStr} for document ${doc.name}";
                in
                  lib.addErrorContext contextMsg (
                    if (builtins.pathExists p)
                    then let
                      contents = builtins.readFile p;
                    in
                      findLatexPackages {fileContents = contents;}
                    else lib.warn "LaTeX file ${pathStr} not found for document ${doc.name}" {}
                  ))
                (lib.lists.unique searchPaths));

              # Normalize document-specific extraTexPackages
              # Pass discovered packages for function-type extraTexPackages
              docExtraPackagesNormalized = lib.addErrorContext "while normalizing extraTexPackages for document ${doc.name}" (
                normalizeHelpers.normalizeExtraTexPackages {
                  extraTexPackages = doc.extraTexPackages;
                  discoveredPackages = discovered;
                }
              );

              # Merge module-level and document-level extra packages
              # Document-level takes precedence
              mergedExtraPackages = moduleExtraPackagesNormalized // docExtraPackagesNormalized;
            in {
              inherit doc discovered;
              extraNormalized = mergedExtraPackages;
            })
            documents;

          # Collect all discovered packages from all documents
          allDiscoveredPackages =
            lib.lists.foldl (
              acc: processedDoc:
                acc // processedDoc.discovered
            ) {}
            processedDocuments;

          # Collect all extra packages (including module-level)
          # Module-level packages are already included in each document's extraNormalized
          allExtraPackagesAttrs =
            lib.lists.foldl (
              acc: processedDoc:
                acc // processedDoc.extraNormalized
            ) {}
            processedDocuments;

          # For the unified environment, also ensure module-level packages are included
          # (in case there are no documents)
          unifiedAdditionalPackages =
            moduleExtraPackagesNormalized // allDiscoveredPackages // allExtraPackagesAttrs;

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

          # Modified mkDoc function to pass pre-normalized packages
          mkDoc = doc: let
            processedDoc = lib.lists.findFirst (p: p.doc == doc) null processedDocuments;
            extraPackagesForDoc =
              if processedDoc != null
              then processedDoc.extraNormalized
              else {};
          in
            (pkgs.callPackage ../lib/mkLatexPdfDocument.nix {}) (doc
              // {
                # Pass pre-normalized packages under a different parameter name
                # to avoid double-normalization
                _preNormalizedExtraPackages = extraPackagesForDoc;
                # Don't pass extraTexPackages - let mkLatexPdfDocument use the raw one if needed
              });

          docPkgs = builtins.listToAttrs (map (doc: {
              name = lib.removeSuffix ".pdf" doc.name;
              value = mkDoc doc;
            })
            documents);

          # Create packages for the unified TeX Live environment and latexmk
          # Always create these if we have module-level packages, even without documents
          unifiedPackages =
            if documents != [] || moduleExtraTexPackages != []
            then {
              texlive-unified = unifiedTexEnv;
              latexmk-unified = pkgs.writeShellScriptBin "latexmk" ''
                exec ${lib.getExe' unifiedTexEnv "latexmk"} "$@"
              '';
            }
            else {};

          # VSCode integration
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

          # VSCode settings function for custom overrides
          vscodeSettingsWithOverrides = overrides:
            pkgs.writeTextFile {
              name = "vscode-settings-custom";
              destination = "/.vscode/settings.json";
              text = mkVSCodeSettings overrides;
            };

          # VSCode integration packages (only include derivations)
          vscodeIntegration =
            if documents != [] || moduleExtraTexPackages != []
            then let
              # Default VSCode settings package
              vscodeSettings = pkgs.writeTextFile {
                name = "vscode-settings";
                destination = "/.vscode/settings.json";
                text = mkVSCodeSettings {};
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
                  echo "📦 Using unified TeX Live environment with packages from:"
                  ${
                    if documents != []
                    then ''
                      echo "   - ${toString (builtins.length documents)} configured document(s)"
                    ''
                    else ""
                  }
                  ${
                    if moduleExtraTexPackages != []
                    then ''
                      echo "   - Module-level extraTexPackages"
                    ''
                    else ""
                  }
                '';
              };
            in {
              vscode-settings = vscodeSettings;
              # Don't include vscodeSettingsWithOverrides here - it's a function
              vscode-devshell = vscodeDevShell;
            }
            else {};
        in {
          packages =
            if documents == [] && moduleExtraTexPackages == []
            then {}
            else
              docPkgs
              // unifiedPackages
              // vscodeIntegration
              // (
                if documents != []
                then {default = mkDoc (builtins.head documents);}
                else {}
              );

          devShells = let
            hasDocuments = documents != [];
            hasModulePackages = moduleExtraTexPackages != [];
            hasAnyConfig = hasDocuments || hasModulePackages;
          in {
            vscode =
              if hasAnyConfig && vscodeIntegration ? vscode-devshell
              then vscodeIntegration.vscode-devshell
              else
                pkgs.mkShell {
                  buildInputs = [
                    pkgs.texlive.combined.scheme-basic
                    pkgs.ltex-ls
                  ];
                  shellHook = ''
                    ${
                      if !hasAnyConfig
                      then ''
                        echo "⚠️  No LaTeX documents or module-level packages configured"
                        echo "📝 Add documents to latex-utils.documents or packages to latex-utils.extraTexPackages"
                        echo "   to enable full VSCode integration"
                      ''
                      else ''
                        echo "⚠️  VSCode integration failed during processing"
                        echo "🔍 Check your configurations for errors"
                      ''
                    }
                    echo ""
                    echo "Available commands:"
                    echo "  latexmk - Basic LaTeX compilation"
                    echo "  ltex-ls - Language server (for VSCode/editors)"
                  '';
                };
          };

          # Make the VSCode settings override function available as a package builder
          # Users can use it like: nix build .#vscode-settings-custom -- '{"ltex.language": "de-DE"}'
          apps.vscode-settings-custom = {
            type = "app";
            program = "${pkgs.writeShellScript "vscode-settings-custom" ''
              ${lib.getExe pkgs.jq} -n "$1" > settings.json
              echo "Generated VSCode settings in settings.json"
            ''}";
            meta.description = "Generate custom VSCode settings for LaTeX with your overrides";
          };
        })
        # Other modules can extend perSystem here
      ];
  };
}
