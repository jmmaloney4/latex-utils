{
  pkgs,
  lib,
  findLatexPackages,
}: let
  # Test cases
  testInputBasic = ''
    % A comment
    \\usepackage{foo}
    \\usepackage{foo,bar}
    \\usepackage[options]{baz,qux}
    \\usepackage[opt]{single}
    Not a package line
  '';

  testInputWhitespace = ''
    \\usepackage  {  spaced }
    \\usepackage{  leading, trailing  }
  '';

  testInputMalformed = ''
    \\usepackage{missingEnd
    \\usepackage missingBraces
    \\usepackage{}
  '';

  testInputComments = ''
    % \\usepackage{shouldNotBeFound}
    \\usepackage{shouldBeFound} % real package
    % just a comment
  '';

  # Helper to extract and sort package names
  getSortedNames = input:
    lib.lists.sort builtins.lessThan (builtins.attrNames (findLatexPackages {fileContents = input;}));
in {
  # Test: Basic package extraction from valid \usepackage commands.
  # Purpose: Verifies that standard package declarations (single, multiple, with options) are correctly identified.
  basic = {
    expr = getSortedNames testInputBasic;
    expected = ["bar" "baz" "foo" "qux" "single"];
  };

  # Test: Package extraction with varied whitespace around package names and braces.
  # Purpose: Ensures robustness in parsing despite inconsistent spacing in \usepackage commands.
  whitespace = {
    expr = getSortedNames testInputWhitespace;
    expected = ["leading" "spaced" "trailing"];
  };

  # Test: Behavior with malformed \usepackage commands.
  # Purpose: Verifies that the function handles gracefully (and doesn't extract from) common malformations like missing braces or content.
  malformed = {
    expr = getSortedNames testInputMalformed;
    expected = [];
  };

  # Test: Package extraction when \usepackage commands are commented out or followed by comments.
  # Purpose: Ensures that commented-out package declarations are ignored and inline comments don't interfere with parsing.
  comments = {
    expr = getSortedNames testInputComments;
    expected = ["shouldBeFound"];
  };

  # Test: Behavior with empty file content.
  # Purpose: Verifies that providing no input results in no packages found.
  empty = {
    expr = getSortedNames "";
    expected = [];
  };

  # Test: Extraction of multiple packages declared in a single \usepackage command without options.
  # Purpose: Checks correct parsing of comma-separated package lists within a single command.
  multiPackage = {
    expr = getSortedNames ''\\usepackage{amsmath, amsthm, amssymb, mathtools}'';
    expected = ["amsmath" "amssymb" "amsthm" "mathtools"];
  };

  # Test: Extraction of multiple packages declared in a single \usepackage command with options.
  # Purpose: Ensures options part is correctly ignored and all packages in the comma-separated list are found.
  multiPackageWithOptions = {
    expr = getSortedNames ''\\usepackage[options]{foo, bar, baz}'';
    expected = ["bar" "baz" "foo"];
  };

  # Test: Extraction with a single package name in \usepackage and a CTAN mapping comment.
  # Purpose: Verifies that both the used package name and the TeX Live package name from the CTAN comment are extracted (e.g. tikz -> pgf).
  ctanSingle = {
    expr = getSortedNames ''\\usepackage{tikz} % CTAN: pgf'';
    expected = ["pgf" "tikz"];
  };

  # Test: Extraction with a single package name in \usepackage and multiple TeX Live names in a CTAN comment.
  # Purpose: Checks that the used package and all packages listed in the CTAN comment are extracted.
  ctanMultiple = {
    expr = getSortedNames ''\\usepackage{somepackage} % CTAN: ctanpackage1, ctanpackage2'';
    expected = ["ctanpackage1" "ctanpackage2" "somepackage"];
  };

  # Test: Extraction with multiple packages in \usepackage and multiple TeX Live names in a CTAN comment.
  # Purpose: Ensures all names from both \usepackage and the CTAN comment are aggregated.
  ctanMultiUseAndCTAN = {
    expr = getSortedNames ''\\usepackage{foo, bar} % CTAN: baz, qux'';
    expected = ["bar" "baz" "foo" "qux"];
  };

  # Test: Deduplication and whitespace handling for names extracted from \usepackage and CTAN comments.
  # Purpose: Verifies that package names are deduplicated (e.g. if 'foo' is in \usepackage and CTAN comment) and whitespace in CTAN comments is handled.
  ctanDedupWhitespace = {
    expr = getSortedNames ''\\usepackage{foo} % CTAN: foo, bar  ,   baz'';
    expected = ["bar" "baz" "foo"];
  };
}
