{
  pkgs,
  system,
  inputs,
  ...
}: let
  # Shared nix-unit integration fixtures so expensive flake evaluation happens
  # once per system in flake.nix instead of once per importing test file.
  flake = import ./flake.nix;

  testHarnessOutputsArgs = {
    self = flake;
    nixpkgs = inputs.nixpkgs;
    flake-parts = inputs.flake-parts;
    latex-utils = inputs.latex-utils;
    inherit system;
  };

  evalTestFlake = flakeDef: outputsArgs:
    import ./test-flake-helpers.nix {
      inherit flakeDef outputsArgs;
    };

  harnessOutputs = evalTestFlake flake testHarnessOutputsArgs;

  minimalTexSrc = pkgs.writeTextDir "main.tex" ''
    \documentclass{article}
    \usepackage{amsmath}
    \begin{document}
    Hello, world!
    \end{document}
  '';

  singleDocumentFlake = {
    inputs = {
      nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
      flake-parts.url = "github:hercules-ci/flake-parts";
    };
    outputs = outputsArgs @ {
      flake-parts,
      nixpkgs,
      system ? builtins.currentSystem or "x86_64-linux",
      ...
    }:
      flake-parts.lib.mkFlake {
        self =
          outputsArgs.self
          // {
            inputs = {inherit (outputsArgs) nixpkgs flake-parts;};
          };
        inputs = {inherit (outputsArgs) nixpkgs flake-parts;};
      } {
        systems = [system];
        imports = [../modules/latex-utils.nix];
        latex-utils.documents = [
          {
            name = "test.pdf";
            src = minimalTexSrc;
          }
        ];
      };
  };

  singleDocumentOutputs = evalTestFlake singleDocumentFlake (
    testHarnessOutputsArgs
    // {
      self = singleDocumentFlake;
    }
  );

  emptyDocumentsFlake = {
    inputs = {
      nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
      flake-parts.url = "github:hercules-ci/flake-parts";
    };
    outputs = outputsArgs @ {
      flake-parts,
      nixpkgs,
      ...
    }:
      flake-parts.lib.mkFlake {
        self =
          outputsArgs.self
          // {
            inputs = {inherit (outputsArgs) nixpkgs flake-parts;};
          };
        inputs = {inherit (outputsArgs) nixpkgs flake-parts;};
      } {
        systems = [system];
        imports = [../modules/latex-utils.nix];
        latex-utils.documents = [];
      };
  };

  emptyDocumentsOutputs = evalTestFlake emptyDocumentsFlake (
    testHarnessOutputsArgs
    // {
      self = emptyDocumentsFlake;
    }
  );
in {
  inherit evalTestFlake harnessOutputs singleDocumentOutputs emptyDocumentsOutputs;
}
