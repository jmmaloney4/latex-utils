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
  basic = {
    expr = getSortedNames testInputBasic;
    expected = ["bar" "baz" "foo" "qux" "single"];
  };

  whitespace = {
    expr = getSortedNames testInputWhitespace;
    expected = ["leading" "spaced" "trailing"];
  };

  malformed = {
    expr = getSortedNames testInputMalformed;
    expected = [];
  };

  comments = {
    expr = getSortedNames testInputComments;
    expected = ["shouldBeFound"];
  };

  empty = {
    expr = getSortedNames "";
    expected = [];
  };

  multiPackage = {
    expr = getSortedNames ''\\usepackage{amsmath, amsthm, amssymb, mathrsfs, mathtools}'';
    expected = ["amsmath" "amssymb" "amsthm" "mathrsfs" "mathtools"];
  };

  multiPackageWithOptions = {
    expr = getSortedNames ''\\usepackage[options]{foo, bar, baz}'';
    expected = ["bar" "baz" "foo"];
  };

  ctanSingle = {
    expr = getSortedNames ''\\usepackage{tikz} % CTAN: pgf'';
    expected = ["pgf" "tikz"];
  };

  ctanMultiple = {
    expr = getSortedNames ''\\usepackage{somepackage} % CTAN: ctanpackage1, ctanpackage2'';
    expected = ["ctanpackage1" "ctanpackage2" "somepackage"];
  };

  ctanMultiUseAndCTAN = {
    expr = getSortedNames ''\\usepackage{foo, bar} % CTAN: baz, qux'';
    expected = ["bar" "baz" "foo" "qux"];
  };

  ctanDedupWhitespace = {
    expr = getSortedNames ''\\usepackage{foo} % CTAN: foo, bar  ,   baz'';
    expected = ["bar" "baz" "foo"];
  };
}
