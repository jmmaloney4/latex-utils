# Comprehensive Example: All Features and Fixes
#
# This example demonstrates:
# 1. Module-level extraTexPackages
# 2. Document-level extraTexPackages with various formats
# 3. VSCode integration with fallback devShell
# 4. Unified TeX environment working correctly
# 5. No double-normalization issues
{
  description = "Comprehensive LaTeX project with latex-utils";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    latex-utils.url = "github:jmmaloney4/latex-utils";
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];

      imports = [
        inputs.latex-utils.modules.flake.latex-utils
      ];

      # MODULE-LEVEL PACKAGES
      # These apply to ALL documents and environments
      latex-utils.extraTexPackages = discovered:
        [
          # Always include these base packages
          "amsmath"
          "amssymb"
          "mathtools"
          "geometry"
          "hyperref"
          "biblatex"
        ]
        ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
          # Platform-specific packages
          "darwin-tex-utils" # hypothetical package
        ];

      # DOCUMENTS
      latex-utils.documents = [
        # Document 1: Simple document with string-based extras
        {
          name = "simple-report.pdf";
          src = ./simple-report;
          extraTexPackages = [
            "xcolor" # Additional color support
            "listings" # Code listings
          ];
        }

        # Document 2: Advanced with derivation-based extras
        {
          name = "research-paper.pdf";
          src = ./research-paper;
          extraTexPackages = [
            pkgs.texlive.tikz # Using derivation directly
            pkgs.texlive.pgfplots # For plots
          ];
        }

        # Document 3: Dynamic package selection with function
        {
          name = "thesis.pdf";
          src = ./thesis;
          extraTexPackages = discovered:
          # Add algorithm packages if algorithms are used
            if builtins.hasAttr "algorithm" discovered
            then [
              "algorithmicx"
              "algpseudocode"
              "algorithm2e"
            ]
            # Add chemistry packages if chemistry is used
            else if builtins.hasAttr "chemfig" discovered
            then [
              "chemformula"
              "chemmacros"
            ]
            # Default packages
            else [
              "glossaries"
              "makeindex"
            ];
        }

        # Document 4: Mixed derivations and strings
        {
          name = "presentation.pdf";
          src = ./presentation;
          inputFile = "slides.tex";
          extraTexPackages = [
            "beamer" # String format
            pkgs.texlive.pgfpages # Derivation format
            "xcolor"
          ];
        }
      ];

      perSystem = {
        config,
        self',
        pkgs,
        ...
      }: {
        # DEVELOPMENT SHELLS
        devShells = {
          # Default shell with full VSCode integration
          default = config.devShells.latex-utils;

          # Minimal TeX shell without VSCode
          minimal = pkgs.mkShell {
            name = "minimal-latex-shell";
            inputsFrom = [config.latex-utils.unifiedTexShell];
            buildInputs = [pkgs.git];
          };

          # Writing-focused shell
          writing = pkgs.mkShell {
            name = "writing-focused-shell";
            inputsFrom = [config.latex-utils.vscodeShell];
            buildInputs = [
              pkgs.aspell # Spell checking
              pkgs.languagetool # Grammar checking
              pkgs.hunspell # Additional spell checking
            ];
            shellHook = ''
              echo "📝 Writing environment ready!"
              echo "Available tools: aspell, languagetool, hunspell"
            '';
          };

          # Research shell with additional tools
          research = pkgs.mkShell {
            name = "research-shell";
            inputsFrom = [config.latex-utils.vscodeShell];
            buildInputs = [
              pkgs.pandoc # Document conversion
              pkgs.zotero # Reference management
              pkgs.imagemagick # Image processing
              pkgs.inkscape # Vector graphics
              pkgs.gnuplot # Plotting
            ];
            shellHook = ''
              echo "🔬 Research environment ready!"
              echo "Available tools: pandoc, imagemagick, inkscape, gnuplot"
            '';
          };
        };

        # CUSTOM PACKAGES
        packages = {
          # Custom latexmk wrapper with specific flags
          latexmk-fast = pkgs.writeShellScriptBin "latexmk-fast" ''
            exec ${pkgs.lib.getExe' self'.packages.texlive "latexmk"} \
              -pdf -pdflatex="pdflatex -interaction=nonstopmode" \
              -use-make "$@"
          '';

          # Document validation script
          validate-docs = pkgs.writeShellScriptBin "validate-docs" ''
            #!/usr/bin/env bash
            set -e
            echo "🔍 Validating LaTeX documents..."

            # Check for common LaTeX errors
            for tex_file in $(find . -name "*.tex"); do
              echo "Checking $tex_file..."
              # Add your validation logic here
              ${pkgs.lib.getExe' self'.packages.texlive "chktex"} "$tex_file" || true
            done

            echo "✅ Validation complete!"
          '';
        };

        # CUSTOM APPLICATIONS
        apps = {
          # Quick document builder
          build-all = {
            type = "app";
            program = pkgs.writeShellScript "build-all" ''
              #!/usr/bin/env bash
              set -e
              echo "🔨 Building all LaTeX documents..."

              ${pkgs.lib.concatMapStringsSep "\n" (doc: ''
                  echo "📄 Building ${doc.name}..."
                  nix build .#${pkgs.lib.removeSuffix ".pdf" doc.name}
                '')
                config.latex-utils.documents}

              echo "✅ All documents built successfully!"
            '';
            meta.description = "Build all configured LaTeX documents";
          };

          # Document statistics
          doc-stats = {
            type = "app";
            program = pkgs.writeShellScript "doc-stats" ''
              #!/usr/bin/env bash
              echo "📊 LaTeX Project Statistics"
              echo "============================="
              echo "Documents: ${toString (builtins.length config.latex-utils.documents)}"
              echo "Module packages: ${toString (builtins.length config.latex-utils.extraTexPackages)}"
              echo ""
              echo "Documents:"
              ${pkgs.lib.concatMapStringsSep "\n" (doc: ''
                  echo "  - ${doc.name}"
                '')
                config.latex-utils.documents}
            '';
            meta.description = "Show statistics about the LaTeX project";
          };
        };
      };
    };
}
# Key Benefits Demonstrated:
#
# 1. **Module-level packages** reduce duplication across documents
# 2. **Multiple input formats** for extraTexPackages work seamlessly
# 3. **No double-normalization** - derivations are handled correctly
# 4. **Resilient devShells** - always available, even with errors
# 5. **Unified environment** includes all packages from all sources
# 6. **Platform-specific** package handling with functions
# 7. **Custom apps** can leverage the unified environment

