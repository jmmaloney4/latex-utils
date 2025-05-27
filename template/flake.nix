{
  inputs = {
    nixpkgs.url = github:NixOS/nixpkgs/nixos-unstable;
    flake-parts.url = github:hercules-ci/flake-parts;
    latex-utils = {
      url = "github:jmmaloney4/latex-utils";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };
  };
  outputs = inputs@{ nixpkgs, flake-parts, latex-utils, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];
      imports = [ inputs.latex-utils.modules.latex-utils ];
      latex-utils.enable = true;
      perSystem = { pkgs, config, ... }: {
        packages.default = config.mkLatexPdfDocument {
          name = "mydocument";
          src = ./.;
          texPackages = {
            inherit (pkgs.texlive) amscls beamer;
          };
          # inputFile = "main.tex";
        };
      };
    };
}
