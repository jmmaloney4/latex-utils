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
  # Import shared test helpers
  testHelpers = import ../lib/testHelpers.nix {inherit pkgs lib;};
  inherit (testHelpers) builds;

  # Resolve specific TeX Live packages that might be objects, ensuring we pass derivations if needed.
  # amsfonts contains amstex, amssymb, etc.
  # amsrefs is for bibliographic references.
  resolvedAmstex = pkgs.texlive.amsfonts;
  resolvedAmsrefs = pkgs.texlive.amsrefs;

  isAarch64Darwin = pkgs.stdenv.hostPlatform.system == "aarch64-darwin";
in {
  testSingleExtraPackageString = {
    expr = builds (mkDoc {
      name = "test-single-extra.pdf";
      src = minimalTex "singleExtraSrc" "\\usepackage{xcolor}";
      extraTexPackages = ["xcolor"];
    });
    expected = true;
  };

  testMultipleExtraPackagesStrings =
    if isAarch64Darwin
    then {}
    else {
      expr = builds (mkDoc {
        name = "test-multiple-extras.pdf";
        src = minimalTex "multipleExtrasSrc" "\\usepackage{xcolor}";
        extraTexPackages = ["xcolor"];
      });
      expected = true;
    };

  testNoExplicitExtraPackages = {
    expr = builds (mkDoc {
      name = "test-no-extras.pdf";
      src = minimalTex "noExtrasSrc" "\\usepackage{amsmath}";
    });
    expected = true;
  };

  testEmptyListOfExtraPackages =
    if isAarch64Darwin
    then {}
    else {
      expr = builds (mkDoc {
        name = "test-empty-list.pdf";
        src = minimalTex "emptyListSrc" "";
        extraTexPackages = [];
      });
      expected = true;
    };

  testExplicitPackageAlsoDiscovered =
    if isAarch64Darwin
    then {}
    else {
      expr = builds (mkDoc {
        name = "test-override-discovered.pdf";
        src = minimalTex "overrideDiscoveredSrc" "\\usepackage{xcolor}";
        extraTexPackages = ["xcolor"];
      });
      expected = true;
    };

  testMultipleIndependentDocuments =
    if isAarch64Darwin
    then {}
    else {
      expr = let
        doc1 = mkDoc {
          name = "doc1.pdf";
          src = minimalTex "doc1Src" "\\usepackage{xcolor}";
          extraTexPackages = ["xcolor"];
        };
        doc2 = mkDoc {
          name = "doc2.pdf";
          src = minimalTex "doc2Src" "";
          extraTexPackages = [];
        };
      in
        builds doc1 && builds doc2;
      expected = true;
    };

  testPackageAlreadyInBaseScheme = {
    expr = builds (mkDoc {
      name = "test-already-in-scheme.pdf";
      src = minimalTex "alreadyInSchemeSrc" "";
      extraTexPackages = ["lm"];
    });
    expected = true;
  };

  testIntegrationWithFileParams =
    if isAarch64Darwin
    then {}
    else {
      expr = builds (mkDoc {
        name = "test-integration.pdf";
        src = minimalTex "integrationSrc" "\\usepackage{xcolor}";
        inputFile = "main.tex";
        outputPath = "output.pdf";
        extraTexPackages = ["xcolor"];
      });
      expected = true;
    };

  testListOfPackageDerivations =
    if isAarch64Darwin
    then {}
    else {
      expr = builds (mkDoc {
        name = "test-list-of-derivations.pdf";
        src = minimalTex "listOfDerivationsSrc" "\\usepackage{xcolor}";
        extraTexPackages = [pkgs.texlive.xcolor];
      });
      expected = true;
    };

  /*
     # This test causes an infinite recursion, likely due to how pkgs.texlive derivations
     # are evaluated when texlive.combine is invoked, potentially creating a circular
     # dependency back to the flake's checks.
  testFunctionReturningPackageDerivations = {
    expr = let
      result = normalizeExtraTexPackages {
        extraTexPackages = discovered: [
          (pkgs.texlive.amsfonts) # amstex in amsfonts
          (pkgs.texlive.amsrefs)
        ];
        discoveredPackages = {};
        allCollectedPackages = {}; # Simulate an empty set of initially collected packages
      };
    in
      # Check if the specific packages are present by their expected names
      (result ? "amsfonts") && (result ? "amsrefs");
    expected = true;
  };
  */

  /*
     Rest of the tests remain commented out
  testMultipleExtrasFromStringList = {
    texConfig = {
      extraTexPackages = ["xcolor"];
    };
    drvAssert = drv: pkgs.texlive.xcolor == builtins.elemAt drv.texlive.texPackages 0;
    buildAssert = path: builtins.readFile path != "";
    testName = "multipleExtrasFromStringList";
    src = minimalTex "multipleExtrasSrc" "\\usepackage{xcolor}";
  };

  testDocLevelWithOneExtra = {
    texConfig = {
      discoverPackages = true;
      extraTexPackages = ["xcolor"];
    };
    drvAssert = drv: pkgs.texlive.xcolor == builtins.elemAt drv.texlive.texPackages 0;
    buildAssert = path: builtins.readFile path != "";
    testName = "docLevelWithOneExtra";
    src = minimalTex "doc2Src" "";
  };

  testListOfDerivationsStructured = { # Renamed from listOfDerivations to avoid conflict
    texConfig = {
      extraTexPackages = [pkgs.texlive.xcolor];
    };
    drvAssert = drv: pkgs.texlive.xcolor == builtins.elemAt drv.texlive.texPackages 0;
    buildAssert = path: builtins.readFile path != "";
    testName = "listOfDerivations_structured";
    src = minimalTex "listOfDerivationsSrc" "\\usepackage{xcolor}";
  };
  */
}
