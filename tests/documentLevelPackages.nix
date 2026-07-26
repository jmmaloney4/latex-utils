{
  pkgs,
  lib,
}: let
  # Import normalization helpers like the module does
  normalizeHelpers = import ../lib/normalizeExtraTexPackages.nix {inherit pkgs lib;};

  # Import shared test helpers
  testHelpers = import ../lib/testHelpers.nix {inherit pkgs lib;};
  inherit (testHelpers) builds;

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

  # Minimal base set for testing aggregation and withPackages logic.
  # Heavy packages (biblatex, biber, luaotfload, fontspec, lm, cm, ec,
  # tex-gyre) are intentionally omitted — they bloat the transitive closure
  # and can OOM the eval process in CI runners with limited memory.
  # The tests here validate set operations and withPackages-derivation structure,
  # not TeX functionality, so light packages suffice.
  unifiedTexPackages =
    {
      inherit
        (pkgs.texlive)
        latex-bin
        latexmk
        xcolor
        ;
      scheme = pkgs.texlive.scheme-basic;
    }
    // unifiedAdditionalPackages;

  # Convert the merged attrset to a list for withPackages.
  # The // merge above ensures unifiedAdditionalPackages wins for overlapping
  # keys, matching the pre-migration combine semantics, instead of including
  # both and producing conflicting derivations.
  texlivePackagesList = builtins.attrValues unifiedTexPackages;

  unifiedTexEnv = pkgs.texlive.withPackages (_: texlivePackagesList);

  # Expected packages that should be in the unified environment
  expectedDocumentPackages = ["enumitem" "algorithms" "tikzposter"];
  expectedModulePackages = ["amsmath"];
in {
  # Test: Compare the sorted list of all package names in unifiedAdditionalPackages against the expected combined list.
  # Purpose: Provides a comprehensive check that exactly the expected packages (module and document-level) are present.
  testUnifiedPackagesList = {
    expr = lib.lists.sort builtins.lessThan (builtins.attrNames unifiedAdditionalPackages);
    expected = lib.lists.sort builtins.lessThan (
      expectedModulePackages ++ expectedDocumentPackages
    );
  };

  # Test: Check if the 'extraNormalized' attribute for the first processed document contains the correct merged packages.
  # Purpose: Verifies the per-document package merging logic, ensuring module packages are combined with document-specific ones.
  testProcessedDocumentsCorrect = {
    expr = let
      firstDoc = builtins.head processedDocuments;
      firstDocPackages = builtins.attrNames firstDoc.extraNormalized;
    in
      lib.lists.sort builtins.lessThan firstDocPackages;
    # Expects: "algorithms" (doc1), "amsmath" (module), "enumitem" (doc1)
    expected = ["algorithms" "amsmath" "enumitem"];
  };

  # Test: Check if the final unified TeX Live environment (pkgs.texlive.withPackages result) is a buildable derivation.
  # Purpose: Ensures that the assembled TeX Live environment with all packages is valid and can be built.
  testUnifiedTexEnvBuilds = {
    expr = builds unifiedTexEnv;
    expected = true;
  };

  # Test: Check if all expected document-level packages are present in the actual
  # list passed to pkgs.texlive.withPackages.
  # Purpose: Verifies that document-specific packages are correctly included in
  # the inputs to the final TeX environment. Tests texlivePackagesList (the real
  # withPackages input) rather than the intermediate unifiedTexPackages attrset,
  # so the test stays coupled to the migrated behavior.
  testUnifiedTexEnvContainsDocumentPackages = {
    expr = let
      # Extract a comparable name from each package entry.
      # TeX Live package objects have a `pkgs` list (use head's pname).
      # Plain derivations have `pname` directly.
      packageName = pkg:
        if builtins.hasAttr "pkgs" pkg
        then (builtins.head pkg.pkgs).pname
        else pkg.pname or (pkg.name or "");
      packageNames = map packageName texlivePackagesList;
      hasPackage = pkg: builtins.elem pkg packageNames;
    in
      lib.all hasPackage expectedDocumentPackages;
    expected = true;
  };
}
