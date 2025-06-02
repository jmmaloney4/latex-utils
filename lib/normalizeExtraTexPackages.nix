{
  pkgs,
  lib,
  ...
}: {
  # Normalizes extraTexPackages to an attrset of derivations
  # Accepts:
  # - List of strings (package names from pkgs.texlive)
  # - List of derivations
  # - List of TeX Live package objects (e.g., pkgs.texlive.amsfonts)
  # - Function returning list of derivations or TeX Live package objects
  normalizeExtraTexPackages = {
    extraTexPackages,
    discoveredPackages,
  }:
    with lib; let
      # Helper to check if something is a TeX Live package object
      isTexLivePackage = obj:
        (builtins.isAttrs obj)
        && (obj ? pkgs)
        && (builtins.isList obj.pkgs)
        && (obj.pkgs == [] || lib.isDerivation (builtins.head obj.pkgs));

      # Helper to convert list of strings to derivations
      stringsToDerivations = strings:
        builtins.listToAttrs (
          map (item: {
            name = item;
            value = pkgs.texlive.${item};
          })
          strings
        );

      # Helper to convert list of derivations to attrset
      derivationsToAttrset = derivations:
        builtins.listToAttrs (
          lib.lists.imap0 (i: drv: {
            name = drv.pname or "custom-package-${toString i}";
            value = drv;
          })
          derivations
        );

      # Helper to convert list of TeX Live package objects to attrset
      texLivePackagesToAttrset = packages:
        builtins.listToAttrs (
          lib.lists.imap0 (i: pkg: let
            # Try to extract a meaningful name from the TeX Live package
            name =
              if pkg.pkgs != [] && ((builtins.head pkg.pkgs) ? pname)
              then (builtins.head pkg.pkgs).pname
              else if pkg.pkgs != [] && ((builtins.head pkg.pkgs) ? name)
              then let
                fullName = (builtins.head pkg.pkgs).name;
                # Extract just the package name part (before version)
                nameParts = lib.strings.splitString "-" fullName;
              in
                if builtins.length nameParts > 0
                then builtins.head nameParts
                else "texlive-package-${toString i}"
              else "texlive-package-${toString i}";
          in {
            inherit name;
            value = pkg;
          })
          packages
        );

      # Helper to determine what type of list we have and convert appropriately
      convertList = items:
        if items == []
        then {}
        else if lib.isString (builtins.head items)
        then
          # List of strings - verify all are strings
          if builtins.all lib.isString items
          then stringsToDerivations items
          else throw "extraTexPackages list must be homogeneous: all strings, all derivations, or all TeX Live package objects"
        else if lib.isDerivation (builtins.head items)
        then
          # List of derivations - verify all are derivations
          if builtins.all lib.isDerivation items
          then derivationsToAttrset items
          else throw "extraTexPackages list must be homogeneous: all strings, all derivations, or all TeX Live package objects. Got list starting with derivation, but found non-derivation."
        else if isTexLivePackage (builtins.head items)
        then
          # List of TeX Live package objects - verify all are TeX Live packages
          if builtins.all isTexLivePackage items
          then texLivePackagesToAttrset items
          else throw "extraTexPackages list must be homogeneous: all strings, all derivations, or all TeX Live package objects. Got list starting with TeX Live package object, but found non-TeX Live package object."
        else throw "extraTexPackages list items must be strings, derivations, or TeX Live package objects, got: ${builtins.typeOf (builtins.head items)} for the first item. Full list: ${toString items}";
    in
      if lib.isList extraTexPackages
      then convertList extraTexPackages
      else if lib.isFunction extraTexPackages
      then
        # Handle function returning list of derivations or TeX Live package objects
        let
          result = extraTexPackages discoveredPackages;
        in
          if lib.isList result
          then convertList result
          else throw "extraTexPackages was a function, but it did not return a list. Instead, it returned a ${builtins.typeOf result}. Value: ${toString result}"
      else throw "extraTexPackages must be a list or function, but it is a ${builtins.typeOf extraTexPackages}. Value: ${toString extraTexPackages}";
}
