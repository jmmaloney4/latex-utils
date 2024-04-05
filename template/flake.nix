{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    latex-utils = {
      url = "github:jackyliu16/latex-utils";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
  };
  outputs = {
    self,
    nixpkgs,
    flake-utils,
    latex-utils,
  }:
    with flake-utils.lib; eachSystem allSystems (system: let
      pkgs = import nixpkgs {inherit system;};
      texPackages = {
        # NOTE: add some latex package you want 
        inherit (pkgs.texlive);
      };
    in {
      packages.default = latex-utils.lib.${system}.mkLatexPdfDocument {
        name = "mydocument";
        src = self;
        inherit texPackages;
        # inputFile = "main.tex";

        # NOTE: you may use you own version of buildPhase, installPhase, stdenv, texPackage
        # buildPhase = ''
        # export PATH="${pkgs.lib.makeBinPath nativeBuildInputs}";
        # mkdir -p .cache/texmf-var
        # cd ${workingDirectory}
        # echo $PWD
        # ls $PWD
        # env TEXMFHOME=.cache TEXMFVAR=.cache/texmf-var \
        #   latexmk -f -interaction=nonstopmode -pdf -lualatex -bibtex \
        #   -jobname=output \
        #   ${inputFile}
        # '';
      };
    });
}
