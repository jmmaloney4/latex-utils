{
  pkgs
}:
args@{
  name
  , src
  , inputPath ? "main.tex"
  , outputPath ? "output.pdf"
  , texPackages ? {}
  , ...
}:
let
  chosenStdenv = args.stdenv or pkgs.stdenvNoCC;
  texEnvironment = pkgs.texlive.combine ({
    inherit (pkgs.texlive)
    scheme-minimal
    latex-bin
    latexmk;
  } // texPackages);

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
    echo $PWD
    ls $PWD
    env TEXMFHOME=.cache TEXMFVAR=.cache/texmf-var \
      latexmk -f -interaction=nonstopmode -pdf -lualatex -bibtex \
      -jobname=${outputPath} \
      ${inputPath}
  '';
  installPhase = args.installPhase or ''
    mkdir -p $out
    cp ${outputPath} $out/
  '';
}

