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
  scheme ? pkgs.texlive.scheme-medium,
  silent ? false,
  ...
}:

with lib; let
  fixedName = if pkgs.lib.strings.hasSuffix ".pdf" name then name else "${name}.pdf";
  chosenStdenv = args.stdenv or pkgs.stdenvNoCC;

  # Import helpers
  findLatexFiles = import ../lib/findLatexFiles.nix { inherit pkgs lib; };
  findLatexPackages = import ../lib/findLatexPackages.nix { inherit pkgs lib; };

  # scan sources for \usepackage{…}
  searchPaths = findLatexFiles { basePath = "${src}/${workingDirectory}"; };
  discovered = builtins.foldl' (a: b: a // b)
               {}
               (map (
                 p: if (builtins.pathExists p) then findLatexPackages { fileContents = builtins.readFile p; } else {}
               ) (pkgs.lib.lists.unique searchPaths));

  allPackages =
    {
      inherit scheme;
      inherit (pkgs.texlive)
        latex-bin latexmk biblatex biber csquotes luaotfload fontspec lm cm ec tex-gyre;
    }
    // discovered
    // texPackages;

  texEnv = pkgs.texlive.combine allPackages;

  raleway = pkgs.raleway;
  dejavu  = pkgs.dejavu_fonts;

  getExe = pkgs.lib.getExe;
  getExe' = pkgs.lib.getExe';

in chosenStdenv.mkDerivation {
  inherit src; name = fixedName;

  nativeBuildInputs =
    (args.nativeBuildInputs or []) ++ [
      texEnv
      pkgs.fontconfig
      raleway
      dejavu
    ];

  phases = args.phases or [ "unpackPhase" "buildPhase" "installPhase" ];

  buildPhase = args.buildPhase or ''
    ls -al
    echo $(pwd)

    export HOME=$(pwd)
    export XDG_CACHE_HOME="$HOME/.cache"
    export TEXMFVAR="$XDG_CACHE_HOME/texmf-var"
    export TEXMFCACHE="$XDG_CACHE_HOME/texmf-var"
    export TEXMFCONFIG="$XDG_CACHE_HOME/texmf-config"
    export TEXMFHOME="$XDG_CACHE_HOME/texmf-home"
    export OSFONTDIR="${raleway}/share/fonts/truetype:${dejavu}/share/fonts/truetype"
    export FONTCONFIG_CACHE_DIR="$XDG_CACHE_HOME/fontconfig"
    export FONTCONFIG_FILE="${pkgs.fontconfig.out}/etc/fonts/fonts.conf"

    mkdir -p "$TEXMFCACHE" "$TEXMFVAR" "$TEXMFCONFIG" "$TEXMFHOME" "$FONTCONFIG_CACHE_DIR"
    mkdir -p "$HOME/.texlive2024/texmf-var"

    echo "==== ENVIRONMENT ===="
    env | grep TEXMF || true
    env | grep XDG_ || true
    env | grep FONT || true
    echo "==== Directory listings ===="
    ls -al "$TEXMFVAR" || true
    ls -al "$TEXMFCACHE" || true
    ls -al "$HOME/.texlive2024/texmf-var" || true
    ls -al "$FONTCONFIG_CACHE_DIR" || true

    ${getExe' pkgs.fontconfig "fc-cache"} -fv \
      "${raleway}/share/fonts/truetype" \
      "${dejavu}/share/fonts/truetype"

    cd ${workingDirectory}

    ${getExe' texEnv "luaotfload-tool"} --update --force

    ${getExe' texEnv "latexmk"} \
      -f -interaction=nonstopmode \
      -pdf -lualatex -bibtex \
      -jobname=output \
      ${inputFile}
  '';

  installPhase = args.installPhase or ''
    mv output.pdf $out
  '';
}
