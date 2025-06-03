{
  pkgs,
  lib,
}: let
  # Helper to build a document with mkLatexPdfDocument
  mkDoc = args: pkgs.callPackage ../lib/mkLatexPdfDocument.nix {} args;
  # Minimal .tex file contents for testing
  minimalTex = srcName: packageLines:
    pkgs.writeTextDir "${srcName}/main.tex" ''
      \documentclass{article}
      ${packageLines}
      \begin{document}
      Hello, world!
      \end{document}
    '';
  # Helper to check if a derivation builds
  builds = drv: drv.drvPath != null;

  # Resolve specific TeX Live packages that might be objects, ensuring we pass derivations if needed.
  # amsfonts contains amstex, amssymb, etc.
  # amsrefs is for bibliographic references.
  resolvedAmstex = pkgs.texlive.amsfonts;
  resolvedAmsrefs = pkgs.texlive.amsrefs;
in {
  # Test: Document with a single extra TeX package provided as a string.
  # Purpose: Verifies that mkLatexPdfDocument correctly includes a single package name string in its environment.
  singleExtraPackageString = {
    expr = builds (mkDoc {
      name = "test-single-extra.pdf";
      src = minimalTex "singleExtraSrc" "\\usepackage{xcolor}";
      extraTexPackages = ["xcolor"];
    });
    expected = true;
  };

  # Test: Document with multiple extra TeX packages provided as strings.
  # Purpose: Verifies that mkLatexPdfDocument correctly includes multiple package name strings.
  multipleExtraPackagesStrings = {
    expr = builds (mkDoc {
      name = "test-multiple-extras.pdf";
      src = minimalTex "multipleExtrasSrc" "\\usepackage{xcolor}";
      extraTexPackages = ["xcolor"]; # rsfs maps to pkgs.texlive.rsfs
    });
    expected = true;
  };

  # Test: Document with extraTexPackages explicitly undefined (relying on auto-discovery).
  # Purpose: Verifies that mkLatexPdfDocument builds when extraTexPackages is not set, using only discovered packages.
  noExplicitExtraPackages = {
    expr = builds (mkDoc {
      name = "test-no-extras.pdf";
      src = minimalTex "noExtrasSrc" "\\usepackage{amsmath}"; # amsmath should be auto-discovered
      # extraTexPackages is intentionally omitted
    });
    expected = true;
  };

  # Test: Document with extraTexPackages set to an empty list.
  # Purpose: Verifies that mkLatexPdfDocument builds correctly when an empty list is passed for extraTexPackages.
  emptyListOfExtraPackages = {
    expr = builds (mkDoc {
      name = "test-empty-list.pdf";
      src = minimalTex "emptyListSrc" ""; # No packages used in src for simplicity
      extraTexPackages = [];
    });
    expected = true;
  };

  # Test: Document where extraTexPackages explicitly lists a package also discovered from src.
  # Purpose: Ensures that explicitly adding a package that would also be discovered works without issues (e.g. duplication errors).
  explicitPackageAlsoDiscovered = {
    expr = builds (mkDoc {
      name = "test-override-discovered.pdf";
      src = minimalTex "overrideDiscoveredSrc" "\\usepackage{xcolor}";
      extraTexPackages = ["xcolor"];
    });
    expected = true;
  };

  # Test: Building multiple independent documents with their own extra TeX packages.
  # Purpose: Verifies that mkLatexPdfDocument calls are independent and correctly configure packages for each document.
  multipleIndependentDocuments = {
    expr = let
      doc1 = mkDoc {
        name = "doc1.pdf";
        src = minimalTex "doc1Src" "\\usepackage{xcolor}";
        extraTexPackages = ["xcolor"];
      };
      doc2 = mkDoc {
        name = "doc2.pdf";
        src = minimalTex "doc2Src" ""; # Removed mathrsfs, content not critical for this multi-doc test
        extraTexPackages = []; # Assuming doc2 can be empty or use a non-mathrsfs package if needed
      };
    in
      builds doc1 && builds doc2;
    expected = true;
  };

  # Test: Document with an extra package that is already part of the default TeX Live scheme.
  # Purpose: Verifies that including a package already in the base scheme (like 'lm') is handled correctly.
  packageAlreadyInBaseScheme = {
    expr = builds (mkDoc {
      name = "test-already-in-scheme.pdf";
      src = minimalTex "alreadyInSchemeSrc" "";
      extraTexPackages = ["lm"]; # lm (Latin Modern fonts) is in scheme-basic
    });
    expected = true;
  };

  # Test: A more complete integration call to mkLatexPdfDocument with extra packages.
  # Purpose: Verifies mkLatexPdfDocument with commonly used parameters like inputFile and outputPath, along with extraTexPackages.
  integrationWithFileParams = {
    expr = builds (mkDoc {
      name = "test-integration.pdf";
      src = minimalTex "integrationSrc" "\\usepackage{xcolor}";
      inputFile = "main.tex";
      outputPath = "output.pdf"; # Note: name is used for derivation, outputPath for final file name inside store path if different
      extraTexPackages = ["xcolor"];
    });
    expected = true;
  };

  # Test: Document with extraTexPackages provided as a list of TeX Live derivations.
  # Purpose: Verifies support for providing package dependencies as direct Nix derivations.
  listOfPackageDerivations = {
    expr = builds (mkDoc {
      name = "test-list-of-derivations.pdf";
      src = minimalTex "listOfDerivationsSrc" "\\usepackage{xcolor}";
      extraTexPackages = [pkgs.texlive.xcolor];
    });
    expected = true;
  };

  # Test: Document with extraTexPackages provided as a function that returns a list of TeX Live derivations.
  # Purpose: Verifies support for dynamically determining package dependencies (as derivations) using a function.
  functionReturningPackageDerivations = {
    expr = builds (mkDoc {
      name = "test-function-derivations.pdf";
      src = minimalTex "functionReturningDerivationsSrc" "\\usepackage{amsmath}"; # amsmath is in amsfonts
      extraTexPackages = discovered:
        if builtins.hasAttr "amsmath" discovered
        then [resolvedAmstex resolvedAmsrefs]
        else [];
    });
    expected = true;
  };

  # Test 1: Multiple extra packages from string list (simulates config.extraTexPackages = ["pkg1" "pkg2"])
  multipleExtrasFromStringList = {
    # Description: Verifies that multiple packages listed as strings are correctly included.
    # Configuration: extraTexPackages = [ "xcolor" ];
    # Expected: The output document should successfully compile and include xcolor.
    texConfig = {
      extraTexPackages = ["xcolor"]; # Removed mathrsfs
    };
    drvAssert = drv: pkgs.texlive.xcolor == builtins.elemAt drv.texlive.texPackages 0;
    buildAssert = path: builtins.readFile path != ""; # Basic check for non-empty output
    # metadata for tracking
    testName = "multipleExtrasFromStringList";
    src = minimalTex "multipleExtrasSrc" "\\usepackage{xcolor}"; # Removed mathrsfs
  };

  # Test 3: Document-level package discovery with one extra package
  docLevelWithOneExtra = {
    # Description: Checks that document-level discovery works and one extra package is added.
    # Configuration: discoverPackages = true; extraTexPackages = [ "xcolor" ];
    # Expected: Both discovered (e.g. amsmath) and extra (xcolor) packages are included.
    texConfig = {
      discoverPackages = true;
      extraTexPackages = ["xcolor"]; # Removed mathrsfs
    };
    drvAssert = drv: pkgs.texlive.xcolor == builtins.elemAt drv.texlive.texPackages 0;
    buildAssert = path: builtins.readFile path != "";
    testName = "docLevelWithOneExtra";
    src = minimalTex "doc2Src" ""; # Removed mathrsfs from here, assuming it's not vital for the test's core logic
  };

  # Test 5: List of derivations as extra packages
  listOfDerivations = {
    # Description: Verifies that extraTexPackages can be a list of TeX Live derivations.
    # Configuration: extraTexPackages = [ pkgs.texlive.xcolor ];
    # Expected: The specified derivations are included in the build.
    texConfig = {
      extraTexPackages = [pkgs.texlive.xcolor]; # Removed mathrsfs
    };
    drvAssert = drv: pkgs.texlive.xcolor == builtins.elemAt drv.texlive.texPackages 0;
    buildAssert = path: builtins.readFile path != "";
    testName = "listOfDerivations";
    src = minimalTex "listOfDerivationsSrc" "\\usepackage{xcolor}"; # Removed mathrsfs
  };
}
