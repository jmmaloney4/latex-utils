# Integration tests for extraTexPackages wiring in mkLatexPdfDocument
#
# Tests that extra TeX packages (strings, derivations, TeX Live objects)
# are correctly wired into the derivation's build environment.
# Uses _preNormalizedExtraPackages to bypass source scanning, avoiding
# the Linux CI sandbox issue (see ADR 014).
#
# Source scanning is tested separately in findLatexPackages.nix.
{
  pkgs,
  lib,
}: let
  mkDoc = args: pkgs.callPackage ../lib/mkLatexPdfDocument.nix {} args;

  # Minimal pre-normalized packages for testing
  xcolor = pkgs.texlive.xcolor;
  amsmath = pkgs.texlive.amsmath;
  amsfonts = pkgs.texlive.amsfonts;
  pgf = pkgs.texlive.pgf;

  # Minimal src -- use builtins.toFile to avoid derivation realization.
  # mkLatexPdfDocument won't access it when _preNormalizedExtraPackages is set.
  dummySrc = builtins.toFile "main.tex" ''
    \documentclass{article}
    \begin{document}
    Hello
    \end{document}
  '';

  # Helper: check that a value is a derivation
  isDeriv = x: lib.isDerivation x;

  # Helper: check derivation has texlive-combined in nativeBuildInputs
  hasTexLiveCombined = drv:
    builtins.any (input:
      lib.strings.hasPrefix "texlive-combined" (input.name or "")
    ) (drv.nativeBuildInputs or []);
in {
  # --- Basic derivation construction ---

  testSingleExtraPackage = {
    expr = isDeriv (mkDoc {
      name = "test-single.pdf";
      src = dummySrc;
      _preNormalizedExtraPackages = {inherit xcolor;};
    });
    expected = true;
  };

  testMultipleExtraPackages = {
    expr = isDeriv (mkDoc {
      name = "test-multiple.pdf";
      src = dummySrc;
      _preNormalizedExtraPackages = {inherit xcolor amsmath;};
    });
    expected = true;
  };

  testNoExtraPackages = {
    expr = isDeriv (mkDoc {
      name = "test-none.pdf";
      src = dummySrc;
      _preNormalizedExtraPackages = {};
    });
    expected = true;
  };

  # --- Package types ---

  testDerivationPackage = {
    expr = isDeriv (mkDoc {
      name = "test-drv.pdf";
      src = dummySrc;
      _preNormalizedExtraPackages = {inherit pgf;};
    });
    expected = true;
  };

  testTexLiveObjectPackage = {
    # amsfonts is a TeX Live "object" (has pkgs attribute), not a plain derivation
    expr = isDeriv (mkDoc {
      name = "test-texlive-obj.pdf";
      src = dummySrc;
      _preNormalizedExtraPackages = {inherit amsfonts;};
    });
    expected = true;
  };

  testMixedPackageTypes = {
    expr = isDeriv (mkDoc {
      name = "test-mixed.pdf";
      src = dummySrc;
      _preNormalizedExtraPackages = {inherit pgf xcolor amsfonts;};
    });
    expected = true;
  };

  # --- Build environment wiring ---

  testDerivationContainsTexLive = {
    expr = hasTexLiveCombined (mkDoc {
      name = "test-env.pdf";
      src = dummySrc;
      _preNormalizedExtraPackages = {inherit xcolor;};
    });
    expected = true;
  };

  testDerivationContainsTexLiveNoExtras = {
    expr = hasTexLiveCombined (mkDoc {
      name = "test-env-noextras.pdf";
      src = dummySrc;
      _preNormalizedExtraPackages = {};
    });
    expected = true;
  };

  # --- Name handling ---

  testNameGetsPdfSuffix = {
    expr = (mkDoc {
      name = "test-suffix";
      src = dummySrc;
      _preNormalizedExtraPackages = {};
    }).name;
    expected = "test-suffix.pdf";
  };

  testNameKeepsExistingSuffix = {
    expr = (mkDoc {
      name = "test-suffix.pdf";
      src = dummySrc;
      _preNormalizedExtraPackages = {};
    }).name;
    expected = "test-suffix.pdf";
  };
}
