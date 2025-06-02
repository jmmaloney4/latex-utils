{
  pkgs,
  lib,
}: let
  normalizeHelpers = import ../lib/normalizeExtraTexPackages.nix {inherit pkgs lib;};

  # Test discovered packages attrset for function tests
  testDiscovered = {
    amsmath = pkgs.texlive.amsmath;
    xcolor = pkgs.texlive.xcolor;
    tikz = pkgs.texlive.pgf; # tikz maps to pgf package
  };

  # Helper to check if a derivation builds
  builds = drv: drv.drvPath != null;

  # Helper to get sorted attribute names from result
  getSortedNames = result: lib.lists.sort builtins.lessThan (builtins.attrNames result);
in {
  # Test list of strings (backward compatibility)
  listOfStrings = {
    expr = let
      result = normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = ["mathrsfs" "xcolor"];
        discoveredPackages = {};
      };
    in
      getSortedNames result;
    expected = ["mathrsfs" "xcolor"];
  };

  # Test list of derivations
  listOfDerivations = {
    expr = let
      result = normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = [pkgs.texlive.mathrsfs pkgs.texlive.xcolor];
        discoveredPackages = {};
      };
    in
      getSortedNames result;
    expected = ["mathrsfs" "xcolor"];
  };

  # Test mixed list of strings and derivations
  mixedList = {
    expr = let
      result = normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = ["mathrsfs" pkgs.texlive.xcolor];
        discoveredPackages = {};
      };
    in
      getSortedNames result;
    expected = ["mathrsfs" "xcolor"];
  };

  # Test function that returns list of strings
  functionReturningStrings = {
    expr = let
      result = normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = discovered:
          if builtins.hasAttr "tikz" discovered
          then ["pgfplots"]
          else ["standalone"];
        discoveredPackages = testDiscovered;
      };
    in
      getSortedNames result;
    expected = ["pgfplots"];
  };

  # Test function that returns list of derivations
  functionReturningDerivations = {
    expr = let
      result = normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = discovered:
          if builtins.hasAttr "amsmath" discovered
          then [pkgs.texlive.amsfonts]
          else [pkgs.texlive.mathtools];
        discoveredPackages = testDiscovered;
      };
    in
      getSortedNames result;
    expected = ["amsfonts"];
  };

  # Test function that returns mixed list
  functionReturningMixed = {
    expr = let
      result = normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = discovered:
          if builtins.hasAttr "xcolor" discovered
          then ["colortbl" pkgs.texlive.xspace]
          else [];
        discoveredPackages = testDiscovered;
      };
    in
      getSortedNames result;
    expected = ["colortbl" "xspace"];
  };

  # Test empty list
  emptyList = {
    expr = let
      result = normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = [];
        discoveredPackages = {};
      };
    in
      getSortedNames result;
    expected = [];
  };

  # Test function returning empty list
  functionReturningEmpty = {
    expr = let
      result = normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = discovered: [];
        discoveredPackages = testDiscovered;
      };
    in
      getSortedNames result;
    expected = [];
  };

  # Test that all derivations in result are valid
  derivationsAreValid = {
    expr = let
      result = normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = ["mathrsfs" pkgs.texlive.xcolor];
        discoveredPackages = {};
      };
      allValid = lib.lists.all (name: builds result.${name}) (builtins.attrNames result);
    in
      allValid;
    expected = true;
  };

  # Test error handling: invalid list item type
  invalidListItemError = {
    expr = let
      shouldFail = builtins.tryEval (normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = ["mathrsfs" 42]; # number is invalid
        discoveredPackages = {};
      });
    in
      shouldFail.success;
    expected = false;
  };

  # Test error handling: function returning non-list
  functionReturningNonListError = {
    expr = let
      shouldFail = builtins.tryEval (normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = discovered: "not-a-list";
        discoveredPackages = testDiscovered;
      });
    in
      shouldFail.success;
    expected = false;
  };

  # Test error handling: invalid input type
  invalidInputTypeError = {
    expr = let
      shouldFail = builtins.tryEval (normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = "not-list-or-function";
        discoveredPackages = {};
      });
    in
      shouldFail.success;
    expected = false;
  };
}
