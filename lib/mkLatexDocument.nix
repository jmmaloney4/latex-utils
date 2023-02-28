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
}:
let
  chosenStdenv = args.stdenv or pkgs.stdenvNoCC;

  discoveredPackages = lib.findLatexPackages { fileContents = (builtins.readFile "${src}/${workingDirectory}/${inputFile}"); };
  texEnvironment = pkgs.texlive.combine ({
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
  } // discoveredPackages // texPackages);

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

