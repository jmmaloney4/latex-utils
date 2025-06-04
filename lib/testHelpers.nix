# Shared Test Helper Functions
{
  pkgs,
  lib,
}: {
  # Helper to check if a derivation or TeX Live package object can be built
  # Handles both:
  # - Regular derivations (with drvPath attribute)
  # - TeX Live package objects (with tlType and pkgs attributes)
  builds = item:
    if lib.isDerivation item
    then item.drvPath != null
    else if (lib.isAttrs item && item ? tlType && lib.isString item.tlType && item ? pkgs && lib.isList item.pkgs)
    then (item.pkgs != [] && (builtins.head item.pkgs).drvPath != null)
    else false; # Not a recognized buildable type
}
