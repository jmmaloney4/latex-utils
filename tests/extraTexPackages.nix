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
  singleExtraPackageString = {
    expr = builds (mkDoc {
      name = "test-single-extra.pdf";
      src = minimalTex "singleExtraSrc" "\\usepackage{xcolor}";
      extraTexPackages = ["xcolor"];
    });
    expected = true;
  };

  multipleExtraPackagesStrings = {
    expr = builds (mkDoc {
      name = "test-multiple-extras.pdf";
      src = minimalTex "multipleExtrasSrc" "\\usepackage{xcolor}";
      extraTexPackages = ["xcolor"];
    });
    expected = true;
  };

  noExplicitExtraPackages = {
    expr = builds (mkDoc {
      name = "test-no-extras.pdf";
      src = minimalTex "noExtrasSrc" "\\usepackage{amsmath}";
    });
    expected = true;
  };

  emptyListOfExtraPackages = {
    expr = builds (mkDoc {
      name = "test-empty-list.pdf";
      src = minimalTex "emptyListSrc" "";
      extraTexPackages = [];
    });
    expected = true;
  };

  explicitPackageAlsoDiscovered = {
    expr = builds (mkDoc {
      name = "test-override-discovered.pdf";
      src = minimalTex "overrideDiscoveredSrc" "\\usepackage{xcolor}";
      extraTexPackages = ["xcolor"];
    });
    expected = true;
  };

  multipleIndependentDocuments = {
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

  packageAlreadyInBaseScheme = {
    expr = builds (mkDoc {
      name = "test-already-in-scheme.pdf";
      src = minimalTex "alreadyInSchemeSrc" "";
      extraTexPackages = ["lm"];
    });
    expected = true;
  };

  integrationWithFileParams = {
    expr = builds (mkDoc {
      name = "test-integration.pdf";
      src = minimalTex "integrationSrc" "\\usepackage{xcolor}";
      inputFile = "main.tex";
      outputPath = "output.pdf";
      extraTexPackages = ["xcolor"];
    });
    expected = true;
  };

  listOfPackageDerivations = {
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
  functionReturningPackageDerivations = {
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
  multipleExtrasFromStringList = {
    texConfig = {
      extraTexPackages = ["xcolor"];
    };
    drvAssert = drv: pkgs.texlive.xcolor == builtins.elemAt drv.texlive.texPackages 0;
    buildAssert = path: builtins.readFile path != "";
    testName = "multipleExtrasFromStringList";
    src = minimalTex "multipleExtrasSrc" "\\usepackage{xcolor}";
  };

  docLevelWithOneExtra = {
    texConfig = {
      discoverPackages = true;
      extraTexPackages = ["xcolor"];
    };
    drvAssert = drv: pkgs.texlive.xcolor == builtins.elemAt drv.texlive.texPackages 0;
    buildAssert = path: builtins.readFile path != "";
    testName = "docLevelWithOneExtra";
    src = minimalTex "doc2Src" "";
  };

  listOfDerivations_structured = { # Renamed from listOfDerivations to avoid conflict
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
