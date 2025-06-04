{lib}: {
  # Define custom types for extraTexPackages
  extraTexPackagesType =
    lib.types.either
    (lib.types.either
      (lib.types.listOf lib.types.str)
      (lib.types.listOf lib.types.package))
    (lib.types.functionTo (lib.types.listOf lib.types.package));

  # Document type definition
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
        type =
          lib.types.either
          (lib.types.either
            (lib.types.listOf lib.types.str)
            (lib.types.listOf lib.types.package))
          (lib.types.functionTo (lib.types.listOf lib.types.package));
        default = [];
        description = ''
          Extra TeX Live packages to include for this document.
          Can be:
          - List of package names (strings): ["'mathrsfs'" "'xcolor'"]
          - List of derivations: [pkgs.texlive.mathrsfs pkgs.myCustomTexPackage]
          - A function that takes `pkgs.texlive` and returns a list of derivations: `texlive: [ texlive.mathrsfs texlive.xcolor ]`

          Note: Lists must be homogeneous (all strings OR all derivations).
          Functions must return lists of derivations.

          See: https://nixos.wiki/wiki/TexLive#Customizing_TeX_Live_environments
        '';
        example = lib.literalExpression ''
          # List of package name strings
          ["'mathrsfs'" "'xcolor'"]

          # List of derivations
          [pkgs.texlive.mathrsfs pkgs.myCustomTexPackage]

          # Function (for dynamic package selection)
          (discovered: if builtins.hasAttr "tikz" discovered
                       then [pkgs.texlive.pgfplots]
                       else [])
        '';
      };
    };
  };
}
