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
}
