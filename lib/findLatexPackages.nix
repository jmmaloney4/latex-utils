# Finding LaTex Packages name as list
# INPUT:str         // the content of a file though readFiles
# OUTPUT:List[str]  // a list of packages names
{
  pkgs,
  lib,
  ...
}: 
  {fileContents}: # List[string]
    with pkgs.lib.attrsets;
    with pkgs.lib.strings; 
    with pkgs.lib.lists;
    let 
      inherit (builtins) trace match head tail split filter readFile isList isNull elemAt length pathExists;
      inherit (pkgs.lib) concatMap concatLists subtractLists splitString genAttrs unique remove
        hasSuffix isDerivation;
      contentsLines = splitString "\n" fileContents;
      # Check if line contains package information
      preprocessLines = builtins.filter (line: (isPackageLines line)) contentsLines; # List[str]: the line contains package info
      # Gain PackageNames
      # processedPackages =  (line: gainPackageNameFromLine line != null) preprocessLines;
      processedPackages = map gainPackageNameFromLine preprocessLines;
      
      # processedPackages = unique (builtins.concatMap gainPackageNameFromLine preprocessLines); # List[str]: the line contains package name
      # texPackages = filterAttrs (y: x: x != null) processedPackages (genAttrs processedPackages (name: attrByPath [name] null pkgs.texlive));

      isPackageLines = line: let # str -> Bool
        res = builtins.match ''\\(usepackage|Requirepackage).*'' line;
      in res != null;

      gainPackageNameFromLine = line: let # str -> List[str]
        matchers = match "\\\\(usepackage|RequirePackage)[^\\{]*\\{([^}]*).*" line; # len=1
        # matchers = builtins.match "^\\\\(usepackage|RequirePackage)[^\\{]*\\{([^\\,]*){comma_times},*\s*([^\\}]*).*" line;
        # NOTE: I have no ideas but seems nix regex doesn't support capture team multiple times 

        undivided = if length matchers == 2 then elemAt matchers 1 else builtins.abort "matchers length incorrect";
        divide =  if hasInfix "," undivided then splitString "," undivided else [ undivided ] ;
        ifPackageNameFormatCorrect = one: let # str -> Bool
          # NOTE: unknown rules "^[a-z](?|.*--)[a-z-]*[a-z]$" one;
          res = builtins.match ".*" one; 
        in res != null;
      in builtins.filter ifPackageNameFormatCorrect divide;    
      # in divide;
        # Check if each name provide by matcher is correct
        # TODO: add more trace output when incorrect.
    in
    # processedPackages  # processedPackages
    # preprocessLines
    processedPackages
    # (gainPackageNameFromLine (builtins.elemAt preprocessLines 0))
    # ifPackageNameFormatCorrect "amsmath"
