{
  pkgs,
  lib,
  ...
}: {
  # Normalizes extraTexPackages to an attrset of derivations
  # Accepts:
  # - List of strings (package names from pkgs.texlive)
  # - List of derivations
  # - Function from discovered packages to list of derivations
  normalizeExtraTexPackages = {
    extraTexPackages,
    discoveredPackages,
  }:
    with lib; let
      # Helper to convert a list of items to derivations
      listToDerivations = items:
        builtins.listToAttrs (
          lib.lists.imap0 (i: item:
            if lib.isString item
            then {
              name = item;
              value = pkgs.texlive.${item};
            }
            else if lib.isDerivation item
            then {
              name = item.pname or "custom-package-${toString i}";
              value = item;
            }
            else throw "extraTexPackages list items must be strings or derivations, got: ${builtins.typeOf item}")
          items
        );
    in
      if lib.isList extraTexPackages
      then
        # Handle list of strings or derivations
        listToDerivations extraTexPackages
      else if lib.isFunction extraTexPackages
      then
        # Handle function from discovered packages to list of derivations
        let
          result = extraTexPackages discoveredPackages;
        in
          if lib.isList result
          then listToDerivations result
          else throw "extraTexPackages function must return a list, got: ${builtins.typeOf result}"
      else throw "extraTexPackages must be a list or function, got: ${builtins.typeOf extraTexPackages}";
}
