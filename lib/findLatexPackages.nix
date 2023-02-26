{ pkgs
  , lib
  , ...
}:
{
  fileContents
}: with pkgs.lib.attrsets; with pkgs.lib.strings; let
  # This is pretty naive at the moment.
  lineToPackageName = (line:
    let
      exact = builtins.match ''^\\usepackage\{([a-zA-Z0-9]*)\}$'' line;
      comment = builtins.match ''^\\usepackage.*\{([a-zA-Z0-9]*)\} \% CTAN: ([a-zA-Z0-9]*)$'' line;
    in 
      if (comment != null) then (elemAt comment 1) else
      if (exact != null) then (elemAt exact 0) else
      null
  );

  lines = splitString "\n" fileContents;
  packageNames = builtins.filter (x: x != null) (builtins.map lineToPackageName lines);
  dbg = builtins.trace (toString packageNames) packageNames;
  texPackages = (genAttrs dbg (name: attrByPath [name] null pkgs.texlive));
  dbg2 = builtins.trace (toString (builtins.attrNames texPackages)) texPackages;
  dbg3 = builtins.trace (toString (map (x: if (x == null) then "null" else "not-null") (builtins.attrValues texPackages))) dbg2;
in filterAttrs (y: x: x != null) dbg3