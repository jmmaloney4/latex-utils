{
  lib,
  flake-parts-lib,
  types,
}: {
  options = {
    # Module-Level Options (Not Per-System)
    # These are global configuration options that apply across all systems
    latex-utils = {
      documents = lib.mkOption {
        type = lib.types.listOf types.docType;
        default = [];
        description = "List of LaTeX documents to build as packages";
      };

      extraTexPackages = lib.mkOption {
        type = types.extraTexPackagesType;
        default = [];
        description = ''
          Extra TeX Live packages to include for ALL documents and environments.
          These packages are merged with document-specific packages.

          Can be:
          - List of package names (strings): ["mathrsfs" "xcolor"]
          - List of derivations: [pkgs.texlive.mathrsfs pkgs.myCustomTexPackage]
          - A function that takes `pkgs.texlive` and returns a list of derivations: `texlive: [ texlive.mathrsfs texlive.xcolor ]`

          Note: Lists must be homogeneous (all strings OR all derivations).
          Functions must return lists of derivations.
          Document-specific packages take precedence in case of conflicts.
        '';
        example = lib.literalExpression ''
          # Common packages for all documents
          ["amsmath" "amssymb" "mathtools" "unicode-math"]
        '';
      };

      enableVSCode = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to enable VS Code integration in devShells";
      };

      flakeFormatter = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to provide a flake formatter for .tex files";
      };

      flakeCheck = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to enable a flake check that rebuilds all PDFs";
      };
    };

    # Per-System Options (Using flake-parts transposition)
    # These define shell fragments that will be available as outputs.latex-utils.${system}.*
    perSystem = flake-parts-lib.mkPerSystemOption {
      options.latex-utils = {
        unifiedTexShell = lib.mkOption {
          type = lib.types.package;
          description = "Composable devshell fragment with unified TeX Live environment";
          readOnly = true;
        };

        vscodeShell = lib.mkOption {
          type = lib.types.package;
          description = "Composable devshell fragment with TeX environment + VSCode integration";
          readOnly = true;
        };
      };
    };
  };
}
