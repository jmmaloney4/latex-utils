{
  pkgs,
  lib,
  documents,
  moduleExtraTexPackages,
  engine ? "lualatex",
}: let
  # Import helpers
  findLatexFiles = import ../../lib/findLatexFiles.nix {inherit pkgs lib;};
  findLatexPackages = import ../../lib/findLatexPackages.nix {inherit pkgs lib;};
  normalizeHelpers = import ../../lib/normalizeExtraTexPackages.nix {inherit pkgs lib;};

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
        (map
          (p: let
            pathStr = toString p;
            contextMsg = "while discovering packages in ${pathStr} for document ${doc.name}";
            rawDiscovered =
              if (builtins.pathExists p)
              then let
                contents = builtins.readFile p;
              in
                findLatexPackages {fileContents = contents;}
              else lib.warn "LaTeX file ${pathStr} not found for document ${doc.name}" {};
          in
            lib.addErrorContext contextMsg rawDiscovered)
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
      inherit doc;
      discovered = discovered;
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
in {
  inherit
    processedDocuments
    allDiscoveredPackages
    allExtraPackagesAttrs
    unifiedAdditionalPackages
    moduleExtraPackagesNormalized
    ;

  # Helper function to create document packages
  mkDoc = doc: let
    processedDoc = lib.lists.findFirst (p: p.doc == doc) null processedDocuments;
    extraPackagesForDoc =
      if processedDoc != null
      then processedDoc.extraNormalized
      else {};
  in
    (pkgs.callPackage ../../lib/mkLatexPdfDocument.nix {}) (doc
      // {
        # Pass pre-normalized packages under a different parameter name
        # to avoid double-normalization
        _preNormalizedExtraPackages = extraPackagesForDoc;
        engine = engine;
        # Don't pass extraTexPackages - let mkLatexPdfDocument use the raw one if needed
      });
}
