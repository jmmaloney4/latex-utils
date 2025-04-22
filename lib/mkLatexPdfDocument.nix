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

with lib; let
  fixedName = if pkgs.lib.strings.hasSuffix ".pdf" name then name else "${name}.pdf";
  chosenStdenv = args.stdenv or pkgs.stdenvNoCC;

  # scan sources for \usepackage{…}
  searchPaths = lib.findLatexFiles { basePath = "${src}/${workingDirectory}"; };
  discovered = builtins.foldl' (a: b: a // b)
               {}
               (map (p: lib.findLatexPackages { fileContents = builtins.readFile p; }) searchPaths);

  allPackages =
    {
      inherit scheme;
      inherit (pkgs.texlive)
        latex-bin latexmk biblatex biber csquotes luaotfload fontspec;
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

    # --- writable caches for LuaLaTeX ------------------------------
    export HOME=$(pwd)
    export XDG_CACHE_HOME="$HOME/.cache"
    export TEXMFCACHE="$XDG_CACHE_HOME/texmf-cache"
    export TEXMFVAR="$XDG_CACHE_HOME/texmf-var"
    export TEXMFCONFIG="$XDG_CACHE_HOME/texmf-config"
    export TEXMFHOME="$XDG_CACHE_HOME/texmf-home" # User-specific TeX files cache
    mkdir -p "$TEXMFCACHE" "$TEXMFVAR" "$TEXMFCONFIG" "$TEXMFHOME"

    # --- make fonts visible ----------------------------------------
    # Set fontconfig cache dir inside build dir
    export FONTCONFIG_CACHE_DIR="$XDG_CACHE_HOME/fontconfig"
    mkdir -p "$FONTCONFIG_CACHE_DIR"

    # Explicitly point fontconfig to its configuration file
    export FONTCONFIG_FILE="${pkgs.fontconfig.out}/etc/fonts/fonts.conf"

    # Run fc-cache
    # Note: OSFONTDIR is usually used by fontconfig itself, but explicitly
    # calling fc-cache with the paths might be more robust here.
    ${getExe' pkgs.fontconfig "fc-cache"} -fv \
      "${raleway}/share/fonts/truetype" \
      "${dejavu}/share/fonts/truetype"

    # --- build ------------------------------------------------------
    cd ${workingDirectory}

    # Make fonts visible to LuaLaTeX
    export OSFONTDIR="${raleway}/share/fonts/truetype:${dejavu}/share/fonts/truetype"

    env

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
