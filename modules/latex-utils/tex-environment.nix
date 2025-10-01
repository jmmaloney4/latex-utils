{
  pkgs,
  lib,
  unifiedAdditionalPackages,
  engine ? "lualatex",
}: let
  # Create unified TeX Live environment with all packages (including base packages)
  unifiedTexPackages =
    {
      inherit
        (pkgs.texlive)
        latex-bin
        latexmk
        latexindent
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
      scheme = pkgs.texlive.scheme-basic;
    }
    // unifiedAdditionalPackages;

  unifiedTexEnv = pkgs.texlive.combine unifiedTexPackages;

  # Wrap ltex-ls to only see the unified TeX Live binaries
  ltexLsWrapped = pkgs.writeShellScriptBin "ltex-ls" ''
    export PATH=${lib.makeBinPath [unifiedTexEnv]}
    exec ${pkgs.ltex-ls}/bin/ltex-ls "\$@"
  '';

  engineCommand = "${lib.getExe' unifiedTexEnv engine} -interaction=nonstopmode -file-line-error -synctex=1 %O %S";
  engineFlag = "-pdflatex=${lib.escapeShellArg engineCommand}";
  defaultLatexmkArgs = [
    "-pdf"
    "-interaction=nonstopmode"
    "-file-line-error"
    "-synctex=1"
    "-recorder"
    "-silent"
    "-bibtex"
    "-output-directory=.latex-build"
    engineFlag
  ];
  defaultLatexmkArgsString = lib.concatStringsSep " " defaultLatexmkArgs;
  defaultLatexmkArgsShell = lib.concatMapStringsSep "\n" (arg: "      \"${arg}\"") defaultLatexmkArgs;

  # Thin latexmk wrapper with shared defaults
  latexmkWrapper = pkgs.writeShellScriptBin "latexmk" ''
        set -euo pipefail

        DEFAULT_ARGS=(
    ${defaultLatexmkArgsShell}
        )

        CMD_ARGS=()

        if [ -n "''${LATEXMK_OPTS:-}" ]; then
          eval "CMD_ARGS+=( ''${LATEXMK_OPTS} )"
        else
          CMD_ARGS=("''${DEFAULT_ARGS[@]}")
        fi

        CMD_ARGS+=("$@")

        exec ${lib.getExe' unifiedTexEnv "latexmk"} "''${CMD_ARGS[@]}"
  '';

  # Create packages for the unified TeX Live environment and latexmk
  # Always create these if we have module-level packages, even without documents
  unifiedPackages = {
    texlive = unifiedTexEnv;
    latexmk = latexmkWrapper;
    latexindent = pkgs.writeShellScriptBin "latexindent" ''
      exec ${lib.getExe' unifiedTexEnv "latexindent"} "\$@"
    '';
  };

  # Helper dev shell fragment (no VS Code integration)
  unifiedTexShell = pkgs.mkShell {
    buildInputs = [latexmkWrapper unifiedTexEnv ltexLsWrapped];
    shellHook = ''
      if [ -z "''${LATEXMK_OPTS:-}" ]; then
        export LATEXMK_OPTS="${defaultLatexmkArgsString}"
      fi
      if [ -z "''${LATEX_UTILS_UNIFIED_READY:-}" ]; then
        export LATEX_UTILS_UNIFIED_READY=1
        echo 'Unified TeX Live environment ready.'
      fi
    '';
  };
in {
  inherit
    unifiedTexEnv
    ltexLsWrapped
    unifiedPackages
    unifiedTexShell
    latexmkWrapper
    ;
}
