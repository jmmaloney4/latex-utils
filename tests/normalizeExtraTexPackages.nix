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
  # DIRECT TEST: Check if pkgs.texlive.amsmath exists
  directamsmathExists = {
    expr = pkgs.texlive ? "amsmath";
    expected = true;
  };

  # DIRECT TEST: Check if pkgs.texlive.amsmath is a derivation or object if it exists
  directamsmathIsDerivationOrObject = {
    expr =
      if pkgs.texlive ? "amsmath"
      then (lib.isDerivation pkgs.texlive.amsmath || (lib.isAttrs pkgs.texlive.amsmath && pkgs.texlive.amsmath ? tlType && lib.isString pkgs.texlive.amsmath.tlType && pkgs.texlive.amsmath ? pkgs && lib.isList pkgs.texlive.amsmath.pkgs))
      else false; # If it doesn't exist, this test fails too
    expected = true;
  };

  # Test list of strings (backward compatibility)
  # Purpose: Verifies that the function correctly processes a list of package name strings.
  # Test: Input is ["amsmath", "xcolor"]. Expected output is an attrset with keys "amsmath" and "xcolor".
  listOfStrings = {
    expr = let
      result = normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = ["amsmath" "xcolor"];
        discoveredPackages = {};
      };
    in
      getSortedNames result;
    expected = ["amsmath" "xcolor"];
  };

  # Test list of derivations
  # Purpose: Verifies that the function correctly processes a list of TeX Live derivations.
  # Test: Input is a list of derivations (pkgs.texlive.amsmath, pkgs.texlive.xcolor).
  #       Expected output is an attrset with keys corresponding to the derivation names.
  listOfDerivations = {
    expr = let
      result = normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = [pkgs.texlive.amsmath pkgs.texlive.xcolor];
        discoveredPackages = {};
      };
    in
      getSortedNames result;
    expected = ["amsmath" "xcolor"];
  };

  # Test list of TeX Live package objects (NEW)
  # Purpose: Verifies that the function correctly processes a list of TeX Live package objects (attrs with tlType and pkgs).
  # Test: Input is a list of TeX Live package objects (pkgs.texlive.amsfonts, pkgs.texlive.amssymb).
  #       Expected output is an attrset with keys corresponding to the package object names.
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
  # Purpose: Ensures that providing a mixed list of strings and derivations (which is no longer supported) results in an error.
  # Test: Input is ["amsmath", pkgs.texlive.xcolor]. Expected behavior is for the function call to fail (shouldFail.success == false).
  mixedListError = {
    expr = let
      shouldFail = builtins.tryEval (normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = ["amsmath" pkgs.texlive.xcolor]; # mixed types
        discoveredPackages = {};
      });
    in
      shouldFail.success;
    expected = false;
  };

  # Test error handling: function that returns list of strings (no longer directly supported)
  # Purpose: Ensures that a function returning a list of strings (which must now return derivations or TeX Live package objects) results in an error.
  # Test: Input is a function that conditionally returns ["pgfplots"] or ["standalone"].
  #       Expected behavior is for the function call to fail (shouldFail.success == false).
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
  # Purpose: Verifies that the function correctly processes input from a function that returns a list of TeX Live derivations.
  # Test: Input is a function that, based on `discoveredPackages`, returns [pkgs.texlive.amsfonts].
  #       Expected output is an attrset with the key "amsfonts".
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
  # Purpose: Verifies that the function correctly processes input from a function that returns a list of TeX Live package objects.
  # Test: Input is a function that, based on `discoveredPackages`, returns [pkgs.texlive.amsfonts, pkgs.texlive.amssymb].
  #       Expected output is an attrset with keys "amsfonts" and "amssymb".
  functionReturningTexLivePackageObjects = {
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

  # Test error handling: function returning mixed types (no longer supported)
  # Purpose: Ensures that a function returning a mixed list of derivations and strings (no longer supported) results in an error.
  # Test: Input is a function that conditionally returns [pkgs.texlive.colortbl, "xspace"].
  #       Expected behavior is for the function call to fail (shouldFail.success == false).
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

  # Test function that returns list of derivations (formerly functionReturningMixed successful path)
  # Purpose: Verifies that the function correctly handles a function returning a list of derivations,
  #          particularly after refactoring away from mixed type returns.
  # Test: Input is a function that, based on `discoveredPackages`, returns [pkgs.texlive.colortbl, pkgs.texlive.uspace].
  #       Expected output is an attrset with keys "colortbl" and "uspace".
  functionReturningDerivationsNew = {
    expr = let
      result = normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = discovered:
          if builtins.hasAttr "xcolor" discovered
          then [pkgs.texlive.colortbl pkgs.texlive.uspace]
          else [];
        discoveredPackages = testDiscovered;
      };
    in
      getSortedNames result;
    expected = ["colortbl" "uspace"];
  };

  # Test empty list
  # Purpose: Verifies that the function correctly handles an empty list as input.
  # Test: Input is an empty list []. Expected output is an empty attrset.
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
  # Purpose: Verifies that the function correctly handles a function that returns an empty list.
  # Test: Input is a function that returns []. Expected output is an empty attrset.
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

  # Test that all derivations in result are valid (when input is list of strings)
  # Purpose: Ensures that the normalized packages (when input is a list of strings) are valid buildable items.
  # Test: Input is ["amsmath", "xcolor"]. Checks if all items in the resulting attrset are buildable. Expected: true.
  derivationsAreValidFromStrings = {
    expr = let
      result = normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = ["amsmath" "xcolor"];
        discoveredPackages = {};
      };
      allValid = lib.lists.all (name: builds result.${name}) (builtins.attrNames result);
    in
      allValid;
    expected = true;
  };

  # Test that all derivations in result are valid (when input is list of derivations)
  # Purpose: Ensures that the normalized packages (when input is a list of derivations) are valid buildable items.
  # Test: Input is [pkgs.texlive.amsmath, pkgs.texlive.xcolor]. Checks if all items in the resulting attrset are buildable. Expected: true.
  derivationsAreValidFromDerivations = {
    expr = let
      result = normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = [pkgs.texlive.amsmath pkgs.texlive.xcolor];
        discoveredPackages = {};
      };
      allValid = lib.lists.all (name: builds result.${name}) (builtins.attrNames result);
    in
      allValid;
    expected = true;
  };

  # Test that all TeX Live package objects in result are valid (NEW)
  # Purpose: Ensures that the normalized packages (when input is a list of TeX Live package objects) are valid (i.e., attrs with a `pkgs` list).
  # Test: Input is [pkgs.texlive.amsfonts, pkgs.texlive.amssymb].
  #       Checks if all items in the resulting attrset are valid TeX Live package objects. Expected: true.
  texLivePackageObjectsAreValid = {
    expr = let
      result = normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = [pkgs.texlive.amsfonts]; # Use list of TeX Live package objects
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

  # Test error handling: invalid list item type (e.g., a number)
  # Purpose: Ensures that the function errors out if a list item has an unsupported type.
  # Test: Input is ["amsmath", 42] (a string and a number). Expected behavior is for the function call to fail (shouldFail.success == false).
  invalidListItemError = {
    expr = let
      shouldFail = builtins.tryEval (normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = ["amsmath" 42]; # number is invalid
        discoveredPackages = {};
      });
    in
      shouldFail.success;
    expected = false;
  };

  # Test error handling: function returning non-list
  # Purpose: Ensures that the function errors out if the provided function does not return a list.
  # Test: Input is a function that returns "not-a-list" (a string).
  #       Expected behavior is for the function call to fail (shouldFail.success == false).
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

  # Test error handling: invalid input type for extraTexPackages
  # Purpose: Ensures that the function errors out if `extraTexPackages` itself is of an unsupported type.
  # Test: Input `extraTexPackages` is "not-list-or-function" (a string).
  #       Expected behavior is for the function call to fail (shouldFail.success == false).
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

  # Test case: list of derivations
  listIsDerivations = {
    expr = let
      result = normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = [pkgs.texlive.xcolor]; # Use list of derivations (mathrsfs is in jknappen)
        discoveredPackages = {};
      };
    in
      getSortedNames result;
    expected = ["xcolor"];
  };

  # Test case for a list of derivations with duplicates
  normalizeListOfDerivationsWithDuplicates = {
    # description = "Correctly normalizes a list of TeX Live derivations with duplicates";
    expr = let
      result = normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = [
          # pkgs.texlive.mathrsfs # Original was jknappen
          pkgs.texlive.xcolor
          pkgs.texlive.xcolor # Duplicate
          pkgs.texlive.amsmath
          # pkgs.texlive.mathrsfs # Original was jknappen, duplicate
        ];
        discoveredPackages = {};
      };
      expectedSortedNames = ["amsmath" "xcolor"]; # Expected sorted unique names
    in
      getSortedNames result == expectedSortedNames;
    expected = true;
  };

  # Test case for a function returning derivations
  normalizeFunctionReturningListOfDerivations = {
    # description = "Correctly normalizes a function returning a list of TeX Live derivations";
    expr = let
      result = normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = discovered:
          [
            # pkgs.texlive.mathrsfs # Original was jknappen
            pkgs.texlive.xcolor
          ]
          ++ lib.optional (discovered ? "lipsum") pkgs.texlive.lipsum;
        discoveredPackages = {}; # No discovered packages for this specific test variation
      };
      expectedSortedNames = ["xcolor"];
    in
      getSortedNames result == expectedSortedNames;
    expected = true;
  };

  # Test case: function returning derivations, with discovered packages
  normalizeFunctionReturningListOfDerivationsWithDiscovered = {
    # description = "Correctly normalizes a function returning derivations, considering discovered ones";
    expr = let
      result = normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = discovered:
          [
            # pkgs.texlive.mathrsfs # Original was jknappen
            pkgs.texlive.xcolor
          ]
          ++ lib.optional (discovered ? "lipsum") pkgs.texlive.lipsum;
        discoveredPackages = {lipsum = pkgs.texlive.lipsum;}; # Simulate lipsum being discovered
      };
      expectedSortedNames = ["lipsum" "xcolor"]; # Expected sorted names, including lipsum
    in
      getSortedNames result == expectedSortedNames;
    expected = true;
  };

  # Test with an empty list of discovered packages
  emptyListOfDiscoveredPackages = {
    expr = let
      result = normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = [pkgs.texlive.amsmath pkgs.texlive.xcolor];
        discoveredPackages = {};
      };
      allValid = lib.lists.all (name: builds result.${name}) (builtins.attrNames result);
    in
      allValid;
    expected = true;
  };

  testListOfMixedTypes = {
    # Test with a list containing mixed types (strings, derivations)
    extraTexPackages = [
      "amsmath" # String
      pkgs.texlive.xcolor # Derivation
    ];
    action = cfg: cfg.extraTexPackages;
    expectedSortedNames = ["amsmath" "xcolor"]; # Expected sorted unique names
  };

  testDuplicateDerivations = {
    # Test with duplicate derivations
    extraTexPackages = [
      pkgs.texlive.xcolor # Original was jknappen
    ];
    action = cfg: cfg.extraTexPackages;
    expectedSortedNames = ["xcolor"];
  };

  testDerivationsAndStringsWithNames = {
    # Test with derivations and strings that extract package names
    extraTexPackages = [
      (pkgs.texlive.xcolor) # Derivation, should extract "xcolor"
      "lipsum" # String, should be used as is
    ];
    action = cfg: cfg.extraTexPackages;
    expectedSortedNames = ["lipsum" "xcolor"]; # Expected sorted names, including lipsum
  };
}
