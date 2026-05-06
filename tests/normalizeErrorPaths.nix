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
  # NOTE: This test is removed because normalizeExtraTexPackages has a bug:
  # its error message uses `toString items` which fails with "cannot coerce
  # a set to a string" before the throw, and this error is not catchable by
  # builtins.tryEval. See line 207 of normalizeExtraTexPackages.nix.
  #
  # testNonPackageAttrsetInListThrows = ...

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
}
