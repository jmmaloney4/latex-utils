{
  pkgs,
  lib,
}: let
  # Import normalization helpers like the module does
  normalizeHelpers = import ../lib/normalizeExtraTexPackages.nix {inherit pkgs lib;};

  # Test configuration that mimics the issue reported
  moduleExtraTexPackages = ["amsmath"];

  # Mock documents with document-level packages
  documents = [
    {
      name = "thesis.pdf";
      extraTexPackages = ["enumitem" "algorithms"];
    }
    {
      name = "poster.pdf";
      extraTexPackages = ["tikzposter"];
    }
  ];

  # First, normalize module-level extraTexPackages (like the module does)
  moduleExtraPackagesNormalized = normalizeHelpers.normalizeExtraTexPackages {
    extraTexPackages = moduleExtraTexPackages;
    discoveredPackages = {}; # No discovered packages at module level
  };

  # Process each document exactly like the module does
  processedDocuments =
    map (doc: let
      # Mock discovered packages (empty for simplicity)
      discovered = {};

      # Normalize document-specific extraTexPackages
      docExtraPackagesNormalized = normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = doc.extraTexPackages;
        discoveredPackages = discovered;
      };

      # Merge module-level and document-level extra packages
      mergedExtraPackages = moduleExtraPackagesNormalized // docExtraPackagesNormalized;
    in {
      inherit doc discovered;
      extraNormalized = mergedExtraPackages;
    })
    documents;

  # Collect all discovered packages from all documents (like the module does)
  allDiscoveredPackages =
    lib.lists.foldl (
      acc: processedDoc:
        acc // processedDoc.discovered
    ) {}
    processedDocuments;

  # Collect all extra packages (like the module does)
  allExtraPackagesAttrs =
    lib.lists.foldl (
      acc: processedDoc:
        acc // processedDoc.extraNormalized
    ) {}
    processedDocuments;

  # Create unified environment exactly like the module does
  unifiedAdditionalPackages =
    moduleExtraPackagesNormalized // allDiscoveredPackages // allExtraPackagesAttrs;

  # Create unified TeX Live environment like the module does
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

  # Expected packages that should be in the unified environment
  expectedDocumentPackages = ["enumitem" "algorithms" "tikzposter"];
  expectedModulePackages = ["amsmath"];

  # Helper to check if a derivation builds
  builds = drv: drv.drvPath != null;
in {
  # Test: Compare the sorted list of all package names in unifiedAdditionalPackages against the expected combined list.
  # Purpose: Provides a comprehensive check that exactly the expected packages (module and document-level) are present.
  unifiedPackagesList = {
    expr = lib.lists.sort builtins.lessThan (builtins.attrNames unifiedAdditionalPackages);
    expected = lib.lists.sort builtins.lessThan (
      expectedModulePackages ++ expectedDocumentPackages
    );
  };

  # Test: Check if the 'extraNormalized' attribute for the first processed document contains the correct merged packages.
  # Purpose: Verifies the per-document package merging logic, ensuring module packages are combined with document-specific ones.
  processedDocumentsCorrect = {
    expr = let
      firstDoc = builtins.head processedDocuments;
      firstDocPackages = builtins.attrNames firstDoc.extraNormalized;
    in
      lib.lists.sort builtins.lessThan firstDocPackages;
    # Expects: "algorithms" (doc1), "amsmath" (module), "enumitem" (doc1)
    expected = ["algorithms" "amsmath" "enumitem"];
  };

  # Test: Check if the final unified TeX Live environment (pkgs.texlive.combine result) is a buildable derivation.
  # Purpose: Ensures that the assembled TeX Live environment with all packages is valid and can be built.
  unifiedTexEnvBuilds = {
    expr = builds unifiedTexEnv;
    expected = true;
  };

  # Test: Check if all expected document-level packages are present in the final 'unifiedTexPackages' attrset used for pkgs.texlive.combine.
  # Purpose: Verifies that document-specific packages are correctly included in the inputs to the final TeX environment combination.
  unifiedTexEnvContainsDocumentPackages = {
    expr = let
      hasPackage = pkg: builtins.hasAttr pkg unifiedTexPackages;
    in
      lib.all hasPackage expectedDocumentPackages;
    expected = true;
  };
}
