{ pkgs
  , lib
  , ...
}:
let

in
{ fileContents }: with pkgs.lib.attrsets; with pkgs.lib.strings; let
  buildCTANRegex = n: let 
    prefix = ''^\\usepackage.*\{([A-Za-z0-9_]*).*% CTAN: '';
    packageName = ''([A-Za-z0-9]*)'';
    suffix = ''.*$'';

    reps = pkgs.lib.lists.replicate n packageName;
    str = pkgs.lib.strings.concatStringsSep " " reps;
    in prefix + str + suffix;
  
  processLine = line: n: let
    regex = buildCTANRegex n;
    matches = (builtins.match regex line);
    next = if (matches != null) then (processLine line (n + 1)) else null;
  in if (next != null) then next else matches;

  lineToPackageNames = (line:
    let
      exact = builtins.match ''\\usepackage.*\{([A-Za-z0-9_]*).*'' line;
      multicomment = processLine line 1;
    in (if exact == null then [] else exact) ++ 
    (if multicomment == null then [] else multicomment)
  );

  lines = splitString "\n" fileContents;
  processedLines = builtins.filter (x: x != null) (builtins.map lineToPackageNames lines);
  packageNames = builtins.concatLists processedLines;
  texPackages = filterAttrs (y: x: x != null) (genAttrs packageNames (name: attrByPath [name] null pkgs.texlive));
in texPackages
