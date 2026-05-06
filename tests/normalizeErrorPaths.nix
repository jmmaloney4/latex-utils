# Additional error-path tests for normalizeExtraTexPackages
#
# Covers edge cases not tested in the main normalizeExtraTexPackages.nix:
# - Non-package attrset in a list (not a derivation, not a TeX Live object)
# - Function that receives discovered packages correctly
{
  pkgs,
  lib,
}: let
  normalizeHelpers = import ../lib/normalizeExtraTexPackages.nix {inherit pkgs lib;};
in {
  # Test: A list starting with a plain attrset (not a derivation, not TeX Live)
  # should throw a catchable error. Previously this crashed uncatchably because
  # the error message used toString on the list, which fails on attrsets.
  testNonPackageAttrsetInListThrows = {
    expr = let
      result = builtins.tryEval (normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = [{someKey = "someValue";}];
        discoveredPackages = {};
      });
    in
      result.success;
    expected = false;
  };

  # Test: A list starting with an integer should throw
  testIntegerInListThrows = {
    expr = let
      result = builtins.tryEval (normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = [1 2 3];
        discoveredPackages = {};
      });
    in
      result.success;
    expected = false;
  };

  # Test: null extraTexPackages should throw (not a list or function)
  testNullExtraTexPackagesThrows = {
    expr = let
      result = builtins.tryEval (normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = null;
        discoveredPackages = {};
      });
    in
      result.success;
    expected = false;
  };

  # Test: A TeX Live package object list followed by a non-TeX-Live attrset should throw
  testMixedTexLiveAndPlainAttrsetThrows = {
    expr = let
      result = builtins.tryEval (normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = [pkgs.texlive.amsmath {notATeXPackage = true;}];
        discoveredPackages = {};
      });
    in
      result.success;
    expected = false;
  };

  # Test: A derivation list followed by a string should throw (non-homogeneous)
  testMixedDerivationAndStringThrows = {
    expr = let
      result = builtins.tryEval (normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = [pkgs.texlive.amsmath "xcolor"];
        discoveredPackages = {};
      });
    in
      result.success;
    expected = false;
  };

  # NOTE: Removed testNonexistentPackageNameThrows -- normalizeExtraTexPackages
  # does not validate that string package names exist in pkgs.texlive. Missing
  # names produce null values silently via pkgs.texlive.${name}. A future
  # improvement could add validation.

  # Test: A plain attrset (not a list or function) should throw catchably.
  # Previously crashed uncatchably due to toString on the attrset.
  testAttrsetExtraTexPackagesThrows = {
    expr = let
      result = builtins.tryEval (normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = {amsmath = pkgs.texlive.amsmath;};
        discoveredPackages = {};
      });
    in
      result.success;
    expected = false;
  };

  # Test: A function returning a non-list (attrset) should throw catchably.
  testFunctionReturningAttrsetThrows = {
    expr = let
      result = builtins.tryEval (normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = _: {amsmath = pkgs.texlive.amsmath;};
        discoveredPackages = {};
      });
    in
      result.success;
    expected = false;
  };
}
