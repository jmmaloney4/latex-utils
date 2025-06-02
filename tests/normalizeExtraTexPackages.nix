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

  # Test list of TeX Live package objects (NEW)
  listOfTexLivePackageObjects = {
    expr = let
      result = normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = [pkgs.texlive.amsfonts pkgs.texlive.amssymb];
        discoveredPackages = {};
      };
    in
      getSortedNames result;
    expected = ["amsfonts" "amssymb"];
  };

  # Test error handling: mixed list (no longer supported)
  mixedListError = {
    expr = let
      shouldFail = builtins.tryEval (normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = ["mathrsfs" pkgs.texlive.xcolor]; # mixed types
        discoveredPackages = {};
      });
    in
      shouldFail.success;
    expected = false;
  };

  # Test function that returns list of strings (no longer directly supported, functions must return derivations or TeX Live package objects)
  functionReturningStringsError = {
    expr = let
      shouldFail = builtins.tryEval (normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = discovered:
          if builtins.hasAttr "tikz" discovered
          then ["pgfplots"] # strings not allowed from function
          else ["standalone"];
        discoveredPackages = testDiscovered;
      });
    in
      shouldFail.success;
    expected = false;
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

  # Test function that returns list of TeX Live package objects (NEW)
  functionReturningTexLivePackageObjects = {
    expr = let
      result = normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = discovered:
          if builtins.hasAttr "amsmath" discovered
          then [pkgs.texlive.amsfonts pkgs.texlive.amssymb]
          else [pkgs.texlive.mathtools];
        discoveredPackages = testDiscovered;
      };
    in
      getSortedNames result;
    expected = ["amsfonts" "amssymb"];
  };

  # Test error: function returning mixed types (no longer supported)
  functionReturningMixedError = {
    expr = let
      shouldFail = builtins.tryEval (normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = discovered:
          if builtins.hasAttr "xcolor" discovered
          then [pkgs.texlive.colortbl "xspace"] # mixed types not allowed
          else [];
        discoveredPackages = testDiscovered;
      });
    in
      shouldFail.success;
    expected = false;
  };

  # Test function that returns list of derivations (formerly functionReturningMixed)
  functionReturningDerivationsNew = {
    expr = let
      result = normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = discovered:
          if builtins.hasAttr "xcolor" discovered
          then [pkgs.texlive.colortbl pkgs.texlive.xspace]
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

  # Test that all derivations in result are valid (using listOfStrings now)
  derivationsAreValidFromStrings = {
    expr = let
      result = normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = ["mathrsfs" "xcolor"]; # Use list of strings
        discoveredPackages = {};
      };
      allValid = lib.lists.all (name: builds result.${name}) (builtins.attrNames result);
    in
      allValid;
    expected = true;
  };

  # Test that all derivations in result are valid (using listOfDerivations)
  derivationsAreValidFromDerivations = {
    expr = let
      result = normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = [pkgs.texlive.mathrsfs pkgs.texlive.xcolor]; # Use list of derivations
        discoveredPackages = {};
      };
      allValid = lib.lists.all (name: builds result.${name}) (builtins.attrNames result);
    in
      allValid;
    expected = true;
  };

  # Test that all TeX Live package objects in result are valid (NEW)
  texLivePackageObjectsAreValid = {
    expr = let
      result = normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = [pkgs.texlive.amsfonts pkgs.texlive.amssymb]; # Use list of TeX Live package objects
        discoveredPackages = {};
      };
      allValid = lib.lists.all (
        name: let
          item = result.${name};
        in
          (builtins.isAttrs item) && (item ? pkgs) && (builtins.isList item.pkgs)
      ) (builtins.attrNames result);
    in
      allValid;
    expected = true;
  };

  # Test error handling: invalid list item type (e.g. string in a list of derivations if not all strings)
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
