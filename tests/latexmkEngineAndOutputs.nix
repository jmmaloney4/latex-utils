{
  pkgs,
  lib,
  system,
  inputs,
  ...
}: let
  # Import test harness helpers
  flake = import ./flake.nix;
  testHarnessOutputsArgs = {
    self = flake;
    nixpkgs = inputs.nixpkgs;
    flake-parts = inputs.flake-parts;
    latex-utils = inputs.latex-utils;
    inherit system;
  };
  outputs = import ./test-flake-helpers.nix {
    flakeDef = flake;
    outputsArgs = testHarnessOutputsArgs;
  };

  # Helper to create a minimal TeX source for testing
  minimalTexSrc = pkgs.writeTextDir "main.tex" ''
    \documentclass{article}
    \begin{document}
    Hello, engine!
    \end{document}
  '';

  # Create a test flake with engine override and documents
  testFlakeWithEngine = import ./test-flake-helpers.nix {
    flakeDef = {
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
          self = outputsArgs.self;
          inputs = {
            inherit (outputsArgs) nixpkgs flake-parts;
          };
        } {
          systems = ["x86_64-linux"];
          imports = [../modules/latex-utils.nix];
          latex-utils = {
            latexmk.engine = "xelatex";
            documents = [
              {
                name = "engine-test.pdf";
                src = minimalTexSrc;
              }
            ];
          };
          perSystem = {config, ...}: {};
        };
    };
    outputsArgs = testHarnessOutputsArgs;
  };

  # Shared test helpers
  testHelpers = import ../lib/testHelpers.nix {inherit pkgs lib;};
  inherit (testHelpers) builds;

in {
  # New outputs presence
  testLatexmkrcPackageExists = {
    expr =
      testFlakeWithEngine ? packages
      && testFlakeWithEngine.packages ? ${system}
      && testFlakeWithEngine.packages.${system} ? "latexmkrc";
    expected = true;
  };

  testVscodeRecipesPackageExists = {
    expr =
      testFlakeWithEngine ? packages
      && testFlakeWithEngine.packages ? ${system}
      && testFlakeWithEngine.packages.${system} ? "vscode-latex-workshop-recipes";
    expected = true;
  };

  # Buildability
  testLatexmkrcBuilds = {
    expr = builds testFlakeWithEngine.packages.${system}."latexmkrc";
    expected = true;
  };

  testVscodeRecipesBuilds = {
    expr = builds testFlakeWithEngine.packages.${system}."vscode-latex-workshop-recipes";
    expected = true;
  };
}