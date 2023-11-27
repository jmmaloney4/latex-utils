{
  pkgs,
  lib,
  ...
}: args @ {
  name,
  src,
  workingDirectory ? ".",
  inputFile ? "main.tex",
  outputPath ? "output.pdf",
  texPackages ? {},
  scheme ? pkgs.texlive.scheme-basic,
  silent ? false,
  ...
}:
with pkgs.lib.attrsets; let
  # Make sure our derivation ends in .pdf
  fixedName =
    if pkgs.lib.strings.hasSuffix ".pdf" name
    then name
    else pkgs.lib.strings.concatStrings [name ".pdf"];
  chosenStdenv = args.stdenv or pkgs.stdenvNoCC;

  searchPaths = lib.findLatexFiles {basePath = "${src}/${workingDirectory}";}; 
  discoveredPackages = let
    gainPackFromPath = (path: (lib.findLatexPackages {fileContents = builtins.readFile path;}));
    eachFile = map gainPackFromPath searchPaths; # List[File:List[PackName:str]]
    packNames = builtins.concatLists (builtins.concatLists eachFile); # List[PackName:str]
    detectTexPacks = filterAttrs (y: x: x != null) (genAttrs packNames (name: attrByPath [name] null pkgs.texlive)); # Set[PackName:Derivation]
    undetectTexPacks = filterAttrs (y: x: x == null) (genAttrs packNames (name: attrByPath [name] null pkgs.texlive)); # Set[PackName:Derivation]
  in
    if silent || (undetectTexPacks== {})
    then detectTexPacks
    else pkgs.lib.warn 
      "identified packages (add more with argument 'texPackages'): ${toString (attrNames undetectTexPacks)}." 
      detectTexPacks;

  allPackages =
    {
      inherit scheme;
      inherit
        (pkgs.texlive)
        # basic latex
        latex-bin
        latexmk
        # bibtex stuff
        biblatex
        biber
        csquotes
        ;
    }
    // discoveredPackages
    // texPackages;
  texEnvironment = pkgs.texlive.combine allPackages;
in
  chosenStdenv.mkDerivation rec {
    inherit src;
    name = fixedName;

    nativeBuildInputs =
      args.nativeBuildInputs or []
      ++ (with pkgs; [
        coreutils
        texEnvironment
      ]);

    phases = args.phases or ["unpackPhase" "buildPhase" "installPhase"];

    buildPhase =
      args.buildPhase
      or ''
        export PATH="${pkgs.lib.makeBinPath nativeBuildInputs}";
        mkdir -p .cache/texmf-var
        cd ${workingDirectory}
        echo $PWD
        ls $PWD
        env TEXMFHOME=.cache TEXMFVAR=.cache/texmf-var \
          latexmk -f -interaction=nonstopmode -pdf -lualatex -bibtex \
          -jobname=output \
          ${inputFile}
      '';

    installPhase =
      args.installPhase
      or ''
        mv output.pdf $out
      '';
  }
