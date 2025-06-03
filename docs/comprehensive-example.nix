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
        inputs.latex-utils.flakeModule
      ];

      perSystem = {
        config,
        self',
        pkgs,
        ...
      }: {
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

          # Document 4: No extra packages (uses only module-level)
          {
            name = "minimal.pdf";
            src = ./minimal;
            # No extraTexPackages - relies entirely on module-level
          }
        ];

        # PACKAGES
        # Demonstrating available outputs
        packages = {
          # Custom VSCode settings with language override
          custom-vscode-de = pkgs.writeTextFile {
            name = "vscode-settings-de";
            destination = "/.vscode/settings.json";
            text = builtins.toJSON {
              "ltex.language" = "de-DE";
              "ltex.additionalRules.motherTongue" = "de-DE";
              "latex-workshop.message.warning.show" = false;
            };
          };

          # Example using the unified TeX environment directly
          latex-worksheet-generator = pkgs.writeShellScriptBin "gen-worksheet" ''
            #!/usr/bin/env bash
            echo "Generating worksheet with unified TeX environment..."
            ${self'.packages.latexmk-unified}/bin/latexmk -pdf worksheet.tex
          '';
        };

        # DEVSHELLS
        devShells = {
          # Primary development shell with VSCode integration
          default = self'.devShells.vscode;

          # Custom shell with additional tools
          research = pkgs.mkShell {
            buildInputs = [
              self'.packages.texlive-unified # All packages from all documents
              pkgs.pandoc # Document conversion
              pkgs.gnuplot # Plotting
              pkgs.imagemagick # Image manipulation
            ];

            shellHook = ''
              echo "🔬 Research LaTeX Environment"
              echo "📦 Unified TeX Live with all project packages"
              echo ""
              echo "Available tools:"
              echo "  latexmk   - Build any document"
              echo "  pandoc    - Convert between formats"
              echo "  gnuplot   - Create plots"
              echo "  convert   - Process images"
            '';
          };

          # Minimal shell (demonstrates fallback when no docs configured)
          minimal = pkgs.mkShell {
            buildInputs = [
              pkgs.texlive.combined.scheme-basic
            ];
            shellHook = ''
              echo "📄 Minimal LaTeX Environment"
              echo "ℹ️  Configure documents in latex-utils.documents for full features"
            '';
          };
        };

        # APPS
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
# 8. **VSCode integration** works out of the box

