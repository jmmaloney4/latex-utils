{ pkgs
  , lib
  , ...
}:
args@{
  name
  , src
  , workingDirectory ? "."
  , inputFile ? "main.tex"
  , outputPath ? "output.pdf"
  , texPackages ? {}
  , scheme ? pkgs.texlive.scheme-basic
  , ...
}: with pkgs.lib.debug; with pkgs.lib.attrsets; 
let
  chosenStdenv = args.stdenv or pkgs.stdenvNoCC;

  searchPaths = traceVal (lib.findLatexFiles { basePath = "${src}/${workingDirectory}"; });
  discoveredPackages = let
    eachFile = map (path: (lib.findLatexPackages { fileContents = (builtins.readFile "${src}/${workingDirectory}/${path}"); })) searchPaths;
    eachFile' = traceVal eachFile;
  in traceVal (builtins.foldl' (a: b: a // b) {} eachFile');

  allPackages = {
    inherit scheme;
    inherit (pkgs.texlive)
    # basic latex
    latex-bin
    latexmk

    # bibtex stuff
    biblatex
    biber
    csquotes
    ;
  } // traceVal discoveredPackages // texPackages;
  texEnvironment = pkgs.texlive.combine (traceVal allPackages);

in chosenStdenv.mkDerivation rec {
  inherit name src;
  
  nativeBuildInputs = (args.nativeBuildInputs or []) ++ (with pkgs; [
    coreutils
    texEnvironment
  ]);

  phases = args.phases or ["unpackPhase" "buildPhase" "installPhase"];
  buildPhase = args.buildPhase or ''
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
  installPhase = args.installPhase or ''
    mkdir -p $out
    cp output.pdf $out/${outputPath}
  '';
}

