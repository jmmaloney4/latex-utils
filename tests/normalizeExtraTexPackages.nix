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
  builds = item:
    if lib.isDerivation item
    then item.drvPath != null
    else if (lib.isAttrs item && item ? tlType && lib.isString item.tlType && item ? pkgs && lib.isList item.pkgs)
    then (item.pkgs != [] && (builtins.head item.pkgs).drvPath != null)
    else false; # Not a recognized buildable type

  # Helper to get sorted attribute names from result
  getSortedNames = result: lib.lists.sort builtins.lessThan (builtins.attrNames result);
in {
  # Test: Check that a specific TeX Live package exists and can be checked in conditions.
  # Purpose: Confirms that `pkgs.texlive.amsmath` is available and follows the expected structure (for both object access and drvPath).
  testDirectamsmathExists = {
    expr = pkgs.texlive ? "amsmath";
    expected = true;
  };

  # Test: Check that a specific TeX Live package exists and can be checked in conditions.
  # Purpose: Confirms that `pkgs.texlive.amsmath` is available and follows the expected structure (for both object access and drvPath).
  testDirectamsmathIsDerivationOrObject = {
    expr =
      if pkgs.texlive ? "amsmath"
      then (lib.isDerivation pkgs.texlive.amsmath || (lib.isAttrs pkgs.texlive.amsmath && pkgs.texlive.amsmath ? tlType && lib.isString pkgs.texlive.amsmath.tlType && pkgs.texlive.amsmath ? pkgs && lib.isList pkgs.texlive.amsmath.pkgs))
      else false; # If it doesn't exist, this test fails too
    expected = true;
  };

  # Test: List of strings should be normalized to an attribute set of derivations.
  # Purpose: Verifies that a simple list of package name strings is correctly converted to a {name -> derivation} mapping.
  testListOfStrings = {
    expr = let
      result = normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = ["amsmath" "amsfonts"];
        discoveredPackages = {};
      };
    in
      getSortedNames result;
    expected = ["amsfonts" "amsmath"];
  };

  # Test: List of TeX Live derivations should be normalized to an attribute set.
  # Purpose: Confirms that when derivations are provided directly, they're correctly mapped by name.
  testListOfDerivations = {
    expr = let
      result = normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = [pkgs.texlive.amsmath pkgs.texlive.amsfonts];
        discoveredPackages = {};
      };
    in
      getSortedNames result;
    expected = ["amsfonts" "amsmath"];
  };

  # Test: List of TeX Live package objects should be normalized to an attribute set.
  # Purpose: Ensures that TeX Live package objects (with `tlType` and `pkgs` attributes) are handled correctly.
  testListOfTexLivePackageObjects = {
    expr = let
      result = normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = [pkgs.texlive.amsmath];
        discoveredPackages = {};
      };
    in
      getSortedNames result;
    expected = ["amsmath"];
  };

  # Test: Mixed list of different types should produce an error.
  # Purpose: Verifies that mixing strings and derivations in a single list is rejected with a descriptive error.
  testMixedListError = {
    expr = let
      result = builtins.tryEval (normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = ["amsmath" pkgs.texlive.amsfonts];
        discoveredPackages = {};
      });
    in
      result.success;
    expected = false;
  };

  # Test: Function returning strings should produce an error.
  # Purpose: Confirms that functions returning non-derivation lists are properly rejected.
  testFunctionReturningStringsError = {
    expr = let
      result = builtins.tryEval (normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = _discovered: ["amsmath"];
        discoveredPackages = {};
      });
    in
      result.success;
    expected = false;
  };

  # Test: Function returning derivations should be normalized to an attribute set.
  # Purpose: Verifies that functions returning lists of derivations are correctly processed.
  testFunctionReturningDerivations = {
    expr = let
      result = normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = _discovered: [pkgs.texlive.amsmath pkgs.texlive.amsfonts];
        discoveredPackages = {};
      };
    in
      getSortedNames result;
    expected = ["amsfonts" "amsmath"];
  };

  # Test: Function returning TeX Live package objects should be normalized to an attribute set.
  # Purpose: Ensures that functions returning TeX Live package objects are handled correctly.
  testFunctionReturningTexLivePackageObjects = {
    expr = let
      result = normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = _discovered: [pkgs.texlive.amsmath];
        discoveredPackages = {};
      };
    in
      getSortedNames result;
    expected = ["amsmath"];
  };

  # Test: Function returning mixed types should produce an error.
  # Purpose: Verifies that functions returning mixed-type lists are properly rejected.
  testFunctionReturningMixedError = {
    expr = let
      result = builtins.tryEval (normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = _discovered: ["amsmath" pkgs.texlive.amsfonts];
        discoveredPackages = {};
      });
    in
      result.success;
    expected = false;
  };

  # Test: Function returning derivations (alternative implementation) should be normalized.
  # Purpose: Additional verification that functions returning derivation lists work correctly.
  testFunctionReturningDerivationsNew = {
    expr = let
      result = normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = discoveredPackages: [pkgs.texlive.amsmath];
        discoveredPackages = {};
      };
    in
      getSortedNames result;
    expected = ["amsmath"];
  };

  # Test: Empty list should result in an empty attribute set.
  # Purpose: Verifies that providing no extra packages results in an empty normalized result.
  testEmptyList = {
    expr = let
      result = normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = [];
        discoveredPackages = {};
      };
    in
      builtins.attrNames result;
    expected = [];
  };

  # Test: Function returning empty list should result in an empty attribute set.
  # Purpose: Confirms that functions returning empty lists are handled correctly.
  testFunctionReturningEmpty = {
    expr = let
      result = normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = _discovered: [];
        discoveredPackages = {};
      };
    in
      builtins.attrNames result;
    expected = [];
  };

  # Test: Derivations created from strings should be valid and buildable.
  # Purpose: Ensures that string-to-derivation conversion produces valid derivations with correct drvPath.
  testDerivationsAreValidFromStrings = {
    expr = let
      result = normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = ["amsmath"];
        discoveredPackages = {};
      };
    in
      builds result.amsmath;
    expected = true;
  };

  # Test: Derivations provided directly should be valid and buildable.
  # Purpose: Confirms that directly provided derivations maintain their validity after normalization.
  testDerivationsAreValidFromDerivations = {
    expr = let
      result = normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = [pkgs.texlive.amsmath];
        discoveredPackages = {};
      };
    in
      builds result.amsmath;
    expected = true;
  };

  # Test: TeX Live package objects should be valid and analyzable.
  # Purpose: Verifies that TeX Live package objects are correctly processed and maintain their structure.
  testTexLivePackageObjectsAreValid = {
    expr = let
      result = normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = [pkgs.texlive.amsmath];
        discoveredPackages = {};
      };
    in
      # Check if the result has the expected TexLive package structure
      result.amsmath ? "tlType" && lib.isString result.amsmath.tlType;
    expected = true;
  };

  # Test: Invalid list item should produce an error.
  # Purpose: Confirms that non-string, non-derivation items in lists are properly rejected.
  testInvalidListItemError = {
    expr = let
      result = builtins.tryEval (normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = [42]; # Invalid: number instead of string/derivation
        discoveredPackages = {};
      });
    in
      result.success;
    expected = false;
  };

  # Test: Function returning non-list should produce an error.
  # Purpose: Verifies that functions returning non-list values are properly rejected.
  testFunctionReturningNonListError = {
    expr = let
      result = builtins.tryEval (normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = _discovered: "invalid"; # Must return a list
        discoveredPackages = {};
      });
    in
      result.success;
    expected = false;
  };

  # Test: Invalid input type should produce an error.
  # Purpose: Confirms that non-list, non-function inputs are properly rejected.
  testInvalidInputTypeError = {
    expr = let
      result = builtins.tryEval (normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = "invalid"; # Must be list or function
        discoveredPackages = {};
      });
    in
      result.success;
    expected = false;
  };

  # Test: List containing only derivations should be classified correctly.
  # Purpose: Ensures that TeX Live package objects are processed correctly when provided in a list.
  testListIsDerivations = {
    expr = let
      result = normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = [pkgs.texlive.amsmath pkgs.texlive.amsfonts];
        discoveredPackages = {};
      };
    in
      getSortedNames result;
    expected = ["amsfonts" "amsmath"];
  };

  # Test: List of derivations with duplicates should be deduplicated.
  # Purpose: Verifies that when the same derivation appears multiple times, it's included only once in the result.
  testNormalizeListOfDerivationsWithDuplicates = {
    expr = let
      result = normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = [
          pkgs.texlive.amsmath
          pkgs.texlive.amsfonts
          pkgs.texlive.amsmath # duplicate
        ];
        discoveredPackages = {};
      };
    in
      getSortedNames result;
    expected = ["amsfonts" "amsmath"];
  };

  # Test: Function returning list of derivations should be normalized correctly.
  # Purpose: Ensures that functions returning derivation lists are processed the same as direct lists.
  testNormalizeFunctionReturningListOfDerivations = {
    expr = let
      result = normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = _discovered: [pkgs.texlive.amsmath pkgs.texlive.amsfonts];
        discoveredPackages = {};
      };
    in
      getSortedNames result;
    expected = ["amsfonts" "amsmath"];
  };

  # Test: Function can access discovered packages and use them in logic.
  # Purpose: Verifies that functions receive the correct discoveredPackages argument and can use it.
  testNormalizeFunctionReturningListOfDerivationsWithDiscovered = {
    expr = let
      result = normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = discoveredPackages:
          if discoveredPackages ? "amsmath"
          then [pkgs.texlive.amsfonts] # Add amsfonts if amsmath was discovered
          else [pkgs.texlive.amsmath pkgs.texlive.amsfonts];
        discoveredPackages = {"amsmath" = pkgs.texlive.amsmath;};
      };
    in
      getSortedNames result;
    expected = ["amsfonts"];
  };

  # Test: Empty list of discovered packages should be handled correctly.
  # Purpose: Confirms that the function works correctly when no packages have been discovered.
  testEmptyListOfDiscoveredPackages = {
    expr = let
      result = normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = discoveredPackages:
          if discoveredPackages == {}
          then [pkgs.texlive.amsmath]
          else [];
        discoveredPackages = {};
      };
    in
      getSortedNames result;
    expected = ["amsmath"];
  };
}
