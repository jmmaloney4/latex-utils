{pkgs}: let
  lib = rec {
    trace = message: value: builtins.trace (pkgs.lib.strings.concatStrings ["latex-utils: " message]) value;

    findLatexFiles = import ./findLatexFiles.nix {inherit pkgs lib;};
    findLatexPackages = import ./findLatexPackages.nix {inherit pkgs lib;};
    mkLatexPdfDocument = import ./mkLatexPdfDocument.nix {inherit pkgs lib;};
    mkLatexDocument = trace "mkLatexDocument deprecated in favor of mkLatexPdfDocument." mkLatexPdfDocument;
  };
in
  lib
