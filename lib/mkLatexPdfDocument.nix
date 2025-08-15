{
  pkgs,
  lib,
  ...
}:
/*
Function: mkLatexPdfDocument

Description:
  Builds a LaTeX document into a PDF using `latexmk` with `lualatex`.
  It automatically discovers TeX Live packages from source files (`\usepackage` and
  `% CTAN:` comments) and combines them with explicitly provided `extraTexPackages`.
  It also handles font caching for `lualatex`.

Parameters (passed as an attribute set):
  name (string, required): The base name for the output PDF (e.g., "my-document").
                           If it doesn't end with ".pdf", ".pdf" will be appended.
  src (path, required): The source directory containing the LaTeX files.
  workingDirectory (string, optional, default: "."):
    The subdirectory within `src` where `latexmk` will be executed.
  inputFile (string, optional, default: "main.tex"):
    The main TeX file (relative to `workingDirectory`) to be compiled.
  outputPath (string, optional, default: "output.pdf"):
    The expected name of the PDF file produced by `latexmk` (relative to `workingDirectory`).
    This file will be moved to `$out`.
  extraTexPackages (attrset, list, or function, optional, default: []):
    Additional TeX Live packages to include. Can be:
    - A list of package name strings (e.g., ["amsmath" "xcolor"])
    - A list of TeX Live package derivations (e.g., [pkgs.texlive.amsmath])
    - A list of TeX Live package *objects* (e.g. [pkgs.texlive.amsfonts])
    - A function that takes discovered packages (attrset) and returns one of the above lists.
    - An attrset of already normalized packages (internal use).
    See `normalizeExtraTexPackages.nix` for full details on supported formats.
  _preNormalizedExtraPackages (attrset, optional):
    Internally used by the main module to pass already normalized `extraTexPackages`.
    If provided, `extraTexPackages` is ignored for normalization.
  texPackages (attrset of derivations, optional, default: {}):
    An additional attribute set of TeX Live packages to include, typically for packages
    not found by name in `pkgs.texlive`.
  scheme (derivation, optional, default: pkgs.texlive.scheme-basic):
    The base TeX Live scheme to use.
  silent (boolean, optional, default: false):
    (Currently unused, placeholder for future quieter build options).
  stdenv (derivation, optional, default: pkgs.stdenvNoCC):
    The stdenv to use for building the document.
  nativeBuildInputs (list, optional, default: []):
    Additional native build inputs for the derivation.
  phases (list of strings, optional, default: ["unpackPhase" "buildPhase" "installPhase"]):
    Custom phases for the derivation.
  buildPhase (string, optional):
    Custom build phase script. Overrides the default `latexmk` call.
  installPhase (string, optional):
    Custom install phase script. Overrides the default PDF move.
  engine (string, optional, default: "lualatex"):
    Default engine passed to latexmk (one of: "lualatex", "xelatex", "pdflatex").

Returns:
  derivation: A Nix derivation that builds the LaTeX document into a PDF file.
              The output PDF will be available as `$out`.

Example:
  (callPackage ./mkLatexPdfDocument.nix {}) {
    name = "my-paper";
    src = ./src/my-paper-source;
    inputFile = "paper.tex";
    extraTexPackages = [ "biblatex-ieee" pkgs.texlive.pgfplots ];
  }
*/
args @ {
  name,
  src,
  workingDirectory ? ".",
  inputFile ? "main.tex",
  outputPath ? "output.pdf",
  texPackages ? {},
  scheme ? pkgs.texlive.scheme-basic,
  silent ? false,
  engine ? "lualatex",
  ...
}:
with lib; let
  fixedName =
    if pkgs.lib.strings.hasSuffix ".pdf" name
    then name
    else "${name}.pdf";
  chosenStdenv = args.stdenv or pkgs.stdenvNoCC;

  # Import helpers
  findLatexFiles = import ../lib/findLatexFiles.nix {inherit pkgs lib;};
  findLatexPackages = import ../lib/findLatexPackages.nix {inherit pkgs lib;};
  normalizeHelpers = import ../lib/normalizeExtraTexPackages.nix {inherit pkgs lib;};

  # scan sources for \usepackage{…}
  searchPaths = findLatexFiles {basePath = "${src}/${workingDirectory}";};
  discovered =
    builtins.foldl' (a: b: a // b)
    {}
    (map (
      p:
        if (builtins.pathExists p)
        then findLatexPackages {fileContents = builtins.readFile p;}
        else {}
    ) (pkgs.lib.lists.unique searchPaths));

  # Handle extraTexPackages - check for pre-normalized packages first
  extraTexPackagesAttrs =
    # Check if we have pre-normalized packages from the module
    if args ? _preNormalizedExtraPackages
    then args._preNormalizedExtraPackages
    # Otherwise, check if it's already a non-empty attrset of derivations (pre-normalized)
    else if
      builtins.isAttrs (args.extraTexPackages or {})
      && (args.extraTexPackages or {}) != {}
      && builtins.all (name: lib.isDerivation (args.extraTexPackages.${name})) (builtins.attrNames (args.extraTexPackages or {}))
    then
      # Already normalized, use as is
      args.extraTexPackages or {}
    else
      # Original format (list of strings/derivations or function) - normalize it
      lib.addErrorContext "while normalizing extraTexPackages for document '${args.name}' (src: ${toString args.src})"
      (normalizeHelpers.normalizeExtraTexPackages {
        extraTexPackages = args.extraTexPackages or [];
        discoveredPackages = discovered;
      });

  allPackages =
    {
      inherit scheme;
      inherit
        (pkgs.texlive)
        latex-bin
        latexmk
        biblatex
        biber
        csquotes
        luaotfload
        fontspec
        lm
        cm
        ec
        tex-gyre
        ;
    }
    // discovered
    // texPackages
    // extraTexPackagesAttrs;

  texEnv = pkgs.texlive.combine allPackages;

  getExe = pkgs.lib.getExe;
  getExe' = pkgs.lib.getExe';

  # Prebuild fontconfig cache
  mkFontconfigCache = import ../lib/mkFontconfigCache.nix;
  fontconfigCache = mkFontconfigCache {
    inherit pkgs;
    fonts = [texEnv];
  };
in
  chosenStdenv.mkDerivation {
    inherit src;
    name = fixedName;

    nativeBuildInputs =
      (args.nativeBuildInputs or [])
      ++ [
        texEnv
        pkgs.fontconfig
        fontconfigCache
      ];

    phases = args.phases or ["unpackPhase" "buildPhase" "installPhase"];

    buildPhase =
      args.buildPhase
      or ''
        ls -al
        echo $(pwd)

        export HOME=$(pwd)
        export XDG_CACHE_HOME="$HOME/.cache"
        export TEXMFVAR="$XDG_CACHE_HOME/texmf-var"
        export TEXMFCACHE="$XDG_CACHE_HOME/texmf-var"
        export TEXMFCONFIG="$XDG_CACHE_HOME/texmf-config"
        export TEXMFHOME="$XDG_CACHE_HOME/texmf-home"
        export FONTCONFIG_CACHE_DIR="${fontconfigCache}/fontconfig"
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

        cd ${workingDirectory}

        ${getExe' texEnv "luaotfload-tool"} --update --force

        ${getExe' texEnv "latexmk"} \
          -f -interaction=nonstopmode \
          -pdf -${engine} -bibtex \
          -jobname=output \
          ${inputFile}
      '';

    installPhase =
      args.installPhase
      or ''
        mv output.pdf $out
      '';
  }
