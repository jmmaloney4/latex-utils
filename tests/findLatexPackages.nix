{
  pkgs,
  lib,
  findLatexPackages,
}: let
  # Import shared test helpers
  testHelpers = import ../lib/testHelpers.nix {inherit pkgs lib;};
  inherit (testHelpers) builds;

  # Test cases - using real TeX Live package names
  testInputBasic = ''
    % A comment
    \\usepackage{amsmath}
    \\usepackage{amsmath,amsfonts}
    \\usepackage[options]{xcolor,graphics}
    \\usepackage[opt]{geometry}
    Not a package line
  '';

  testInputWhitespace = ''
    \\usepackage  {  amsmath }
    \\usepackage{  amsfonts, xcolor  }
  '';

  testInputMalformed = ''
    \\usepackage{missingEnd
    \\usepackage missingBraces
    \\usepackage{}
  '';

  testInputComments = ''
    % \\usepackage{amsmath}
    \\usepackage{xcolor} % real package
    % just a comment
  '';

  # Helper to extract and sort package names
  getSortedNames = input:
    lib.lists.sort builtins.lessThan (builtins.attrNames (findLatexPackages {fileContents = input;}));
in {
  # Test: Basic package extraction from valid \usepackage commands.
  # Purpose: Verifies that standard package declarations (single, multiple, with options) are correctly identified.
  testBasic = {
    expr = getSortedNames testInputBasic;
    expected = ["amsfonts" "amsmath" "geometry" "graphics" "xcolor"];
  };

  # Test: Package extraction with varied whitespace around package names and braces.
  # Purpose: Ensures robustness in parsing despite inconsistent spacing in \usepackage commands.
  testWhitespace = {
    expr = getSortedNames testInputWhitespace;
    expected = ["amsfonts" "amsmath" "xcolor"];
  };

  # Test: Behavior with malformed \usepackage commands.
  # Purpose: Verifies that the function handles gracefully (and doesn't extract from) common malformations like missing braces or content.
  testMalformed = {
    expr = getSortedNames testInputMalformed;
    expected = [];
  };

  # Test: Package extraction when \usepackage commands are commented out or followed by comments.
  # Purpose: Ensures that commented-out package declarations are ignored and inline comments don't interfere with parsing.
  testComments = {
    expr = getSortedNames testInputComments;
    expected = ["xcolor"];
  };

  # Test: Behavior with empty file content.
  # Purpose: Verifies that providing no input results in no packages found.
  testEmpty = {
    expr = getSortedNames "";
    expected = [];
  };

  # Test: Extraction of multiple packages declared in a single \usepackage command without options.
  # Purpose: Checks correct parsing of comma-separated package lists within a single command.
  testMultiPackage = {
    expr = getSortedNames ''\\usepackage{amsmath, amsthm, amssymb, mathtools}'';
    expected = ["amsmath" "amssymb" "amsthm" "mathtools"];
  };

  # Test: Extraction of multiple packages declared in a single \usepackage command with options.
  # Purpose: Ensures options part is correctly ignored and all packages in the comma-separated list are found.
  testMultiPackageWithOptions = {
    expr = getSortedNames ''\\usepackage[options]{amsmath, amsfonts, xcolor}'';
    expected = ["amsfonts" "amsmath" "xcolor"];
  };

  # Test: Extraction with a single package name in \usepackage and a CTAN mapping comment.
  # Purpose: Verifies that both the used package name and the TeX Live package name from the CTAN comment are extracted (e.g. tikz -> pgf).
  testCtanSingle = {
    expr = getSortedNames ''\\usepackage{tikz} % CTAN: pgf'';
    expected = ["pgf"]; # both tikz and pgf resolve to the same package
  };

  # Test: Extraction with a single package name in \usepackage and multiple TeX Live names in a CTAN comment.
  # Purpose: Checks that the used package and all packages listed in the CTAN comment are extracted.
  testCtanMultiple = {
    expr = getSortedNames ''\\usepackage{amsmath} % CTAN: amsfonts, amssymb'';
    expected = ["amsfonts" "amsmath" "amssymb"];
  };

  # Test: Extraction with multiple packages in \usepackage and multiple TeX Live names in a CTAN comment.
  # Purpose: Ensures all names from both \usepackage and the CTAN comment are aggregated.
  testCtanMultiUseAndCTAN = {
    expr = getSortedNames ''\\usepackage{amsmath, amsfonts} % CTAN: xcolor, geometry'';
    expected = ["amsfonts" "amsmath" "geometry" "xcolor"];
  };

  # Test: Deduplication and whitespace handling for names extracted from \usepackage and CTAN comments.
  # Purpose: Verifies that package names are deduplicated (e.g. if 'amsmath' is in \usepackage and CTAN comment) and whitespace in CTAN comments is handled.
  testCtanDedupWhitespace = {
    expr = getSortedNames ''\\usepackage{amsmath} % CTAN: amsmath, amsfonts  ,   xcolor'';
    expected = ["amsfonts" "amsmath" "xcolor"];
  };
}
