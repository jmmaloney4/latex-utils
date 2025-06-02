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
      workingDirectory = lib.mkOption {
        type = lib.types.str;
        default = ".";
        description = "Working directory within src for the LaTeX document";
        example = ".";
      };
      extraTexPackages = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = ''
          Extra TeX Live packages (by name, as in pkgs.texlive) to include for this document.
          See: https://nixos.wiki/wiki/TexLive#Customizing_TeX_Live_environments
        '';
        example = ["mathrsfs" "xcolor"];
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

          # Collect all extraTexPackages from all documents
          allExtraTexPackages = lib.lists.unique (
            lib.lists.flatten (map (doc: doc.extraTexPackages) documents)
          );

          # Collect all discovered packages from all documents
          allDiscoveredPackages = lib.lists.foldl (acc: doc: let
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
          in
            acc // discovered) {}
          documents;

          # Convert extraTexPackages (list of strings) to an attrset of pkgs.texlive derivations
          extraTexPackagesAttrs = builtins.listToAttrs (
            map (name: {
              name = name;
              value = pkgs.texlive.${name};
            })
            allExtraTexPackages
          );

          # Combine discovered and extra packages (excluding base packages)
          unifiedAdditionalPackages = allDiscoveredPackages // extraTexPackagesAttrs;

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

          # Modified mkDoc function to use the unified additional packages
          mkDoc = doc:
            (pkgs.callPackage ../lib/mkLatexPdfDocument.nix {}) (doc
              // {
                # Pass only the additional packages, let mkLatexPdfDocument handle base packages
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
        in {
          packages =
            if documents == []
            then {}
            else docPkgs // unifiedPackages // {default = mkDoc (builtins.head documents);};
        })
        # Other modules can extend perSystem here
      ];
  };
}
