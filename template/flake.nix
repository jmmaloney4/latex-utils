{
  inputs = {
    nixpkgs.url = github:NixOS/nixpkgs/nixos-unstable;
    flake-utils.url = github:numtide/flake-utils;
    latex-utils = {
      url = "github:jmmaloney4/latex-utils";
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
    with flake-utils.lib;
      eachSystem allSystems (system: let
        pkgs = import nixpkgs {inherit system;};
        texPackages = {
          inherit (pkgs.texlive) amscls beamer;
        };
      in {
        packages.default = latex-utils.lib.${system}.mkLatexPdfDocument {
          name = "mydocument";
          src = self;
          inherit texPackages;
          # inputFile = "main.tex";
        };
      });
}
