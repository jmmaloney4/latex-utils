# Example: Using module-level extraTexPackages in latex-utils
#
# This example demonstrates how to use the new module-level extraTexPackages
# option to specify common packages for all documents.
{
  description = "Example of module-level extraTexPackages";

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
        pkgs,
        ...
      }: {
        # Module-level packages that apply to ALL documents
        latex-utils.extraTexPackages = [
          # Common math packages used by all documents
          "amsmath"
          "amssymb"
          "mathtools"
          "unicode-math"

          # Common formatting packages
          "geometry"
          "fancyhdr"
          "lastpage"

          # Bibliography support for all
          "biblatex"
          "biber"
        ];

        latex-utils.documents = [
          {
            name = "paper1.pdf";
            src = ./paper1;
            # This document gets all module-level packages PLUS these:
            extraTexPackages = [
              "tikz"
              "pgfplots" # Only needed for paper1
            ];
          }
          {
            name = "paper2.pdf";
            src = ./paper2;
            # This document gets all module-level packages PLUS these:
            extraTexPackages = discovered:
            # Dynamic package selection based on discovered packages
              if builtins.hasAttr "algorithm" discovered
              then ["algorithmicx" "algpseudocode"]
              else [];
          }
          {
            name = "thesis.pdf";
            src = ./thesis;
            # This document only uses module-level packages
            # No document-specific extras needed
          }
        ];
      };
    };
}
# Benefits of this approach:
#
# 1. **DRY (Don't Repeat Yourself)**: Common packages like amsmath, geometry, etc.
#    are specified once at the module level instead of in each document.
#
# 2. **Flexibility**: Each document can still add its own specific packages
#    that aren't needed by others.
#
# 3. **Unified Environment**: The texlive package and devShell include
#    ALL packages (module-level + all document-specific), so you can work on
#    any document in the same environment.
#
# 4. **Works Without Documents**: You can set module-level packages even without
#    any documents configured, which still creates a useful TeX environment.
#
# Example usage patterns:
#
# ## Pattern 1: Research Group Template
# Set module-level packages to your group's standard packages (fonts, bibliography
# style, common math packages), then each paper adds its specific needs.
#
# ## Pattern 2: Course Materials
# Module-level packages include all packages used across lecture notes, assignments,
# and exams. Individual documents add specialized packages as needed.
#
# ## Pattern 3: Book/Thesis Project
# Module-level packages contain the core typesetting stack, while chapters might
# add specialized packages for their content (e.g., chemistry packages for one chapter).

