# Tests for unified TeX Live environment construction
#
# Validates that discovered and explicit packages are correctly aggregated
# and that the unified TeX Live environment (texlive.combine) is properly
# constructed. Pure eval -- no filesystem access.
#
# Source scanning uses findLatexPackages directly with string content.
# Build tests use _preNormalizedExtraPackages to bypass scanning.
{
  pkgs,
  lib,
}: let
  findLatexPackages = import ../lib/findLatexPackages.nix {inherit pkgs lib;};
  mkDoc = args: pkgs.callPackage ../lib/mkLatexPdfDocument.nix {} args;

  # Pre-normalized packages
  xcolor = pkgs.texlive.xcolor;
  amsmath = pkgs.texlive.amsmath;
  pgf = pkgs.texlive.pgf;
  jknapltx = pkgs.texlive.jknapltx;

  # Scan test documents (string content, no filesystem)
  testDoc1Content = ''
    \documentclass{article}
    \usepackage{xcolor}
    \begin{document}
    \textcolor{red}{Hello}
    \end{document}
  '';

  testDoc2Content = ''
    \documentclass{article}
    \usepackage{amsmath}
    \usepackage{tikz} % CTAN: pgf
    \begin{document}
    \begin{equation} x = 1 \end{equation}
    \begin{tikzpicture}\draw (0,0) -- (1,1);\end{tikzpicture}
    \end{document}
  '';

  discovered1 = findLatexPackages {fileContents = testDoc1Content;};
  discovered2 = findLatexPackages {fileContents = testDoc2Content;};

  # Aggregate discovered packages (simulating what document-processing.nix does)
  allDiscovered = discovered1 // discovered2;

  # Explicit extra packages
  extraPackagesAttrs = {inherit jknapltx xcolor;};

  # All packages combined
  allPackages =
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
    // allDiscovered
    // extraPackagesAttrs;

  unifiedTexEnv = pkgs.texlive.combine allPackages;

  # Helpers
  hasPackage = name: builtins.hasAttr name allPackages;
  sortedPackageNames = lib.lists.sort builtins.lessThan (builtins.attrNames allPackages);
in {
  # --- Package discovery ---

  testDoc1DiscoveredPackages = {
    expr = lib.lists.sort builtins.lessThan (builtins.attrNames discovered1);
    expected = ["xcolor"];
  };

  testDoc2DiscoveredPackages = {
    expr = lib.lists.sort builtins.lessThan (builtins.attrNames discovered2);
    expected = ["amsmath" "pgf"]; # tikz maps to pgf via CTAN comment
  };

  testAllDiscoveredAggregated = {
    expr = lib.lists.sort builtins.lessThan (builtins.attrNames allDiscovered);
    expected = ["amsmath" "pgf" "xcolor"];
  };

  # --- Package aggregation ---

  testExplicitPackageCollection = {
    expr = lib.lists.sort builtins.lessThan (builtins.attrNames extraPackagesAttrs);
    expected = ["jknapltx" "xcolor"];
  };

  testMixedDiscoveredAndExtraNames = {
    expr = let
      combined = allDiscovered // extraPackagesAttrs;
    in lib.lists.sort builtins.lessThan (builtins.attrNames combined);
    expected = ["amsmath" "jknapltx" "pgf" "xcolor"];
  };

  testPackageDeduplication = {
    # xcolor appears in both discovered and extra; attrset merge keeps one copy
    expr = lib.lists.count (x: x == "xcolor") (builtins.attrNames (allDiscovered // extraPackagesAttrs));
    expected = 1;
  };

  testUnifiedContainsBasePackages = {
    expr = hasPackage "xcolor" && hasPackage "pgf" && hasPackage "latex-bin";
    expected = true;
  };

  # --- Unified environment ---

  testUnifiedTexLiveBuilds = {
    expr = lib.isDerivation unifiedTexEnv;
    expected = true;
  };

  testUnifiedEnvironmentName = {
    expr = unifiedTexEnv.name or "";
    expected = "texlive-combined-2025";
  };

  # --- Latexmk wrapper ---

  testLatexmkWrapperBuilds = {
    expr = let
      wrapper = pkgs.writeShellScriptBin "latexmk" ''
        exec ${lib.getExe' unifiedTexEnv "latexmk"} "$@"
      '';
    in lib.isDerivation wrapper;
    expected = true;
  };

  testLatexmkWrapperName = {
    expr = let
      wrapper = pkgs.writeShellScriptBin "latexmk" ''
        exec ${lib.getExe' unifiedTexEnv "latexmk"} "$@"
      '';
    in wrapper.name or "";
    expected = "latexmk";
  };

  # --- Document build with unified packages ---

  testDocumentBuildsWithUnifiedPackages = {
    expr = let
      dummySrc = builtins.toFile "main.tex" testDoc1Content;
      drv = mkDoc {
        name = "test1.pdf";
        src = dummySrc;
        _preNormalizedExtraPackages = allDiscovered // extraPackagesAttrs;
      };
    in lib.isDerivation drv;
    expected = true;
  };

  # --- Edge cases ---

  testEmptyDocumentList = {
    expr = lib.lists.unique (lib.lists.flatten (map (doc: []) []));
    expected = [];
  };
}
