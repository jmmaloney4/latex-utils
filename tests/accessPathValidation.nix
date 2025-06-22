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
    \usepackage{amsmath}
    \begin{document}
    Hello, world!
    \end{document}
  '';

  # Create a test flake with documents to ensure perSystem outputs exist
  testFlakeWithDocs = import ./test-flake-helpers.nix {
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
          latex-utils.documents = [
            {
              name = "test.pdf";
              src = minimalTexSrc;
            }
          ];
          perSystem = {config, ...}: {
            # This should make the documented access paths available
          };
        };
    };
    outputsArgs = testHarnessOutputsArgs;
  };
in {
  # Test: config.latex-utils.unifiedTexShell exists (documented in README)
  testUnifiedTexShellPath = {
    expr =
      testFlakeWithDocs ? latex-utils
      && testFlakeWithDocs.latex-utils ? ${system}
      && testFlakeWithDocs.latex-utils.${system} ? unifiedTexShell;
    expected = true;
  };

  # Test: config.latex-utils.vscodeShell exists (documented in README)
  testVscodeShellPath = {
    expr =
      testFlakeWithDocs ? latex-utils
      && testFlakeWithDocs.latex-utils ? ${system}
      && testFlakeWithDocs.latex-utils.${system} ? vscodeShell;
    expected = true;
  };

  # Test: config.devShells.latex-utils exists (documented in README)
  testDevShellLatexUtilsPath = {
    expr =
      testFlakeWithDocs ? devShells
      && testFlakeWithDocs.devShells ? ${system}
      && testFlakeWithDocs.devShells.${system} ? "latex-utils";
    expected = true;
  };

  # Test: Document packages are created (documented build patterns)
  testDocumentPackagesPath = {
    expr =
      testFlakeWithDocs ? packages
      && testFlakeWithDocs.packages ? ${system}
      && testFlakeWithDocs.packages.${system} ? "test";
    expected = true;
  };

  # Test: Default package is set (documented in README)
  testDefaultPackagePath = {
    expr =
      testFlakeWithDocs ? packages
      && testFlakeWithDocs.packages ? ${system}
      && testFlakeWithDocs.packages.${system} ? "default";
    expected = true;
  };

  # Test: External access patterns work (documented for testing/integration)
  testExternalAccessPatterns = {
    expr =
      # outputs.latex-utils.${system}.unifiedTexShell pattern
      outputs ? latex-utils
      && outputs.latex-utils ? ${system}
      && outputs.latex-utils.${system} ? unifiedTexShell
      &&
      # outputs.latex-utils.${system}.vscodeShell pattern
      outputs.latex-utils.${system} ? vscodeShell;
    expected = true;
  };

  # Test: Shell fragments are derivations (composable via inputsFrom)
  testShellFragmentsAreDerivations = {
    expr =
      lib.isDerivation testFlakeWithDocs.latex-utils.${system}.unifiedTexShell
      && lib.isDerivation testFlakeWithDocs.latex-utils.${system}.vscodeShell;
    expected = true;
  };

  # Test: Complete devShell is a derivation
  testCompleteDevShellIsDerivation = {
    expr =
      lib.isDerivation testFlakeWithDocs.devShells.${system}."latex-utils";
    expected = true;
  };

  # Test: Document packages are derivations
  testDocumentPackagesAreDerivations = {
    expr =
      lib.isDerivation testFlakeWithDocs.packages.${system}."test"
      && lib.isDerivation testFlakeWithDocs.packages.${system}."default";
    expected = true;
  };

  # Test: Access paths documented in comprehensive example work
  testComprehensiveExamplePaths = {
    expr = let
      # Simulate the comprehensive example structure
      hasUnifiedShell = testFlakeWithDocs.latex-utils.${system} ? unifiedTexShell;
      hasVscodeShell = testFlakeWithDocs.latex-utils.${system} ? vscodeShell;
      hasLatexUtilsDevShell = testFlakeWithDocs.devShells.${system} ? "latex-utils";
    in
      hasUnifiedShell && hasVscodeShell && hasLatexUtilsDevShell;
    expected = true;
  };

  # Test: Template flake access patterns work
  testTemplateAccessPatterns = {
    expr = let
      # Patterns documented in template/flake.nix
      configPaths =
        testFlakeWithDocs.latex-utils.${system} ? unifiedTexShell
        && testFlakeWithDocs.latex-utils.${system} ? vscodeShell
        && testFlakeWithDocs.devShells.${system} ? "latex-utils";
    in
      configPaths;
    expected = true;
  };
}
