{ pkgs
  , lib
  , ...
}:
{ fileContents }: 
  with pkgs.lib.attrsets; with pkgs.lib.strings; let
  # This is pretty naive at the moment.
  lineToPackageName = (line:
    let
      exact = builtins.match ''\\usepackage\{([A-Za-z0-9_]*).*'' line;
      comment = builtins.match ''^\\usepackage.*% CTAN: ([A-Za-z0-9]*)$'' line;
    in 
      if (comment != null) then (elemAt comment 0) else
      if (exact != null) then (elemAt exact 0) else
      null
  );

  lines = splitString "\n" fileContents;
  packageNames = builtins.filter (x: x != null) (builtins.map lineToPackageName lines);
  texPackages = filterAttrs (y: x: x != null) (genAttrs packageNames (name: attrByPath [name] null pkgs.texlive));
in texPackages
