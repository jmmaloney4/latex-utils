{
  pkgs,
  lib,
  unifiedAdditionalPackages,
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

  # Create packages for the unified TeX Live environment and latexmk
  # Always create these if we have module-level packages, even without documents
  unifiedPackages = {
    texlive = unifiedTexEnv;
    latexmk = pkgs.writeShellScriptBin "latexmk" ''
      exec ${lib.getExe' unifiedTexEnv "latexmk"} "$@"
    '';
  };

  # Helper dev shell fragment (no VS Code integration)
  unifiedTexShell = pkgs.mkShell {
    buildInputs = [unifiedTexEnv ltexLsWrapped];
    shellHook = "echo 'Unified TeX Live environment ready.'";
  };

  # Thin latexmk wrapper
  latexmkWrapper = pkgs.writeShellScriptBin "latexmk" ''
    exec ${lib.getExe' unifiedTexEnv "latexmk"} "$@"
  '';
in {
  inherit
    unifiedTexEnv
    ltexLsWrapped
    unifiedPackages
    unifiedTexShell
    latexmkWrapper
    ;
}
