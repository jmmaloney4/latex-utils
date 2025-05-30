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
in {
  singleExtra = {
    expr = builds (mkDoc {
      name = "test.pdf";
      src = minimalTex "singleExtra" "\\usepackage{xcolor}";
      extraTexPackages = ["xcolor"];
    });
    expected = true;
  };

  multipleExtras = {
    expr = builds (mkDoc {
      name = "test.pdf";
      src = minimalTex "multipleExtras" "\\usepackage{mathrsfs} % CTAN: rsfs\n\\usepackage{xcolor}";
      extraTexPackages = ["rsfs" "xcolor"];
    });
    expected = true;
  };

  noExtras = {
    expr = builds (mkDoc {
      name = "test.pdf";
      src = minimalTex "noExtras" "";
    });
    expected = true;
  };

  emptyList = {
    expr = builds (mkDoc {
      name = "test.pdf";
      src = minimalTex "emptyList" "";
      extraTexPackages = [];
    });
    expected = true;
  };

  overrideDiscovered = {
    expr = builds (mkDoc {
      name = "test.pdf";
      src = minimalTex "overrideDiscovered" "\\usepackage{xcolor}";
      extraTexPackages = ["xcolor"];
    });
    expected = true;
  };

  multipleDocs = {
    expr = let
      doc1 = mkDoc {
        name = "doc1.pdf";
        src = minimalTex "doc1" "\\usepackage{xcolor}";
        extraTexPackages = ["xcolor"];
      };
      doc2 = mkDoc {
        name = "doc2.pdf";
        src = minimalTex "doc2" "\\usepackage{mathrsfs} % CTAN: rsfs";
        extraTexPackages = ["rsfs"];
      };
    in
      builds doc1 && builds doc2;
    expected = true;
  };

  alreadyInScheme = {
    expr = builds (mkDoc {
      name = "test.pdf";
      src = minimalTex "alreadyInScheme" "";
      extraTexPackages = ["lm"]; # lm is in scheme-basic
    });
    expected = true;
  };

  integration = {
    expr = builds (mkDoc {
      name = "test.pdf";
      src = minimalTex "integration" "\\usepackage{xcolor}";
      inputFile = "main.tex";
      outputPath = "output.pdf";
      extraTexPackages = ["xcolor"];
    });
    expected = true;
  };
}
