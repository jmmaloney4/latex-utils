{
  pkgs,
  nixUnitLib,
  ...
}: let
  latexLib = import ../lib/default.nix {inherit pkgs;};
in
  nixUnitLib.addCoverage latexLib {
    trace = {
      testExposed = builtins.isFunction latexLib.trace;
    };

    findLatexFiles = {
      testExposed = builtins.isFunction latexLib.findLatexFiles;
    };

    findLatexPackages = {
      testExposed = builtins.isFunction latexLib.findLatexPackages;
    };

    mkLatexPdfDocument = {
      testExposed = builtins.isFunction latexLib.mkLatexPdfDocument;
    };

    mkLatexDocument = {
      testExposed = builtins.isFunction latexLib.mkLatexDocument;
    };
  }
