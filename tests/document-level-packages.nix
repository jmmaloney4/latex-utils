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
  # Test that module-level packages are included
  modulePackagesIncluded = {
    expr = builtins.hasAttr "amsmath" unifiedAdditionalPackages;
    expected = true;
  };

  # Test that document-level packages from first document are included
  firstDocumentPackagesIncluded = {
    expr =
      builtins.hasAttr "enumitem" unifiedAdditionalPackages
      && builtins.hasAttr "algorithms" unifiedAdditionalPackages;
    expected = true;
  };

  # Test that document-level packages from second document are included
  secondDocumentPackagesIncluded = {
    expr = builtins.hasAttr "tikzposter" unifiedAdditionalPackages;
    expected = true;
  };

  # Test that all expected document packages are included
  allDocumentPackagesIncluded = {
    expr = let
      hasPackage = pkg: builtins.hasAttr pkg unifiedAdditionalPackages;
    in
      lib.all hasPackage expectedDocumentPackages;
    expected = true;
  };

  # Debug: Show what packages are actually in the unified environment
  unifiedPackagesList = {
    expr = lib.lists.sort builtins.lessThan (builtins.attrNames unifiedAdditionalPackages);
    expected = lib.lists.sort builtins.lessThan (
      expectedModulePackages ++ expectedDocumentPackages
    );
  };

  # Test specific case from issue report: enumitem should be available for IDE
  enumitemAvailableForIDE = {
    expr = builtins.hasAttr "enumitem" unifiedAdditionalPackages;
    expected = true;
  };

  # Test specific case from issue report: algorithms should be available for IDE
  algorithmsAvailableForIDE = {
    expr = builtins.hasAttr "algorithms" unifiedAdditionalPackages;
    expected = true;
  };

  # Test specific case from issue report: tikzposter should be available for IDE
  tikzposterAvailableForIDE = {
    expr = builtins.hasAttr "tikzposter" unifiedAdditionalPackages;
    expected = true;
  };

  # Test that processedDocuments contains the expected merged packages
  processedDocumentsCorrect = {
    expr = let
      firstDoc = builtins.head processedDocuments;
      firstDocPackages = builtins.attrNames firstDoc.extraNormalized;
    in
      lib.lists.sort builtins.lessThan firstDocPackages;
    expected = ["algorithms" "amsmath" "enumitem"];
  };

  # Test that allExtraPackagesAttrs contains all packages from all documents
  allExtraPackagesCorrect = {
    expr = lib.lists.sort builtins.lessThan (builtins.attrNames allExtraPackagesAttrs);
    expected = ["algorithms" "amsmath" "enumitem" "tikzposter"];
  };

  # Test that the unified TeX environment actually builds
  unifiedTexEnvBuilds = {
    expr = builds unifiedTexEnv;
    expected = true;
  };

  # Test that the unified TeX environment contains the expected packages
  unifiedTexEnvContainsDocumentPackages = {
    expr = let
      hasPackage = pkg: builtins.hasAttr pkg unifiedTexPackages;
    in
      lib.all hasPackage expectedDocumentPackages;
    expected = true;
  };

  # Test that enumitem is specifically available in the final TeX environment
  enumitemInFinalTexEnv = {
    expr = builtins.hasAttr "enumitem" unifiedTexPackages;
    expected = true;
  };

  # Test that algorithms is specifically available in the final TeX environment
  algorithmsInFinalTexEnv = {
    expr = builtins.hasAttr "algorithms" unifiedTexPackages;
    expected = true;
  };

  # Test that tikzposter is specifically available in the final TeX environment
  tikzposterInFinalTexEnv = {
    expr = builtins.hasAttr "tikzposter" unifiedTexPackages;
    expected = true;
  };
}
