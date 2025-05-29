{
  config,
  lib,
  ...
}: let
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
          mkDoc = doc: (pkgs.callPackage ../lib/mkLatexPdfDocument.nix {}) doc;
          docPkgs = builtins.listToAttrs (map (doc: {
              name = lib.removeSuffix ".pdf" doc.name;
              value = mkDoc doc;
            })
            documents);
          defaultPkg =
            if documents == []
            then null
            else mkDoc (builtins.head documents);
        in {
          packages =
            docPkgs
            // {
              default = defaultPkg;
            };
        })
        # Other modules can extend perSystem here
      ];
  };
}
