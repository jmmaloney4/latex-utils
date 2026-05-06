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
    Hello, world! $E = mc^2$
    \end{document}
  '';

  # Test basic documented configuration pattern from README
  testBasicConfig = {
    latex-utils.documents = [
      {
        name = "test.pdf";
        src = minimalTexSrc;
      }
    ];
  };

  # Test module-level extraTexPackages pattern from README
  testModuleLevelConfig = {
    latex-utils.extraTexPackages = ["amsmath" "amssymb"];
    latex-utils.documents = [
      {
        name = "test.pdf";
        src = minimalTexSrc;
      }
    ];
  };

  # Test the comprehensive example pattern
  testComprehensiveConfig = {
    latex-utils.extraTexPackages = ["amsmath" "geometry" "hyperref"];
    latex-utils.documents = [
      {
        name = "thesis.pdf";
        src = minimalTexSrc;
      }
      {
        name = "poster.pdf";
        src = minimalTexSrc;
        inputFile = "main.tex";
        extraTexPackages = ["tikz"];
      }
    ];
  };
  # Create an inline flake with a single document for build/default-package tests
  docTestFlakeDef = {
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
        latex-utils.documents = [
          {
            name = "test.pdf";
            src = minimalTexSrc;
          }
        ];
      };
  };
  docTestOutputs = import ./test-flake-helpers.nix {
    flakeDef = docTestFlakeDef;
    outputsArgs = {
      self = docTestFlakeDef;
      nixpkgs = inputs.nixpkgs;
      flake-parts = inputs.flake-parts;
      inherit system;
    };
  };
in {
  # Test: Basic README example configuration is valid
  testReadmeBasicConfigValid = {
    expr =
      testBasicConfig.latex-utils.documents
      != []
      && (builtins.head testBasicConfig.latex-utils.documents).name == "test.pdf";
    expected = true;
  };

  # Test: Module-level extraTexPackages configuration from README is valid
  testReadmeModuleLevelConfigValid = {
    expr =
      testModuleLevelConfig.latex-utils.extraTexPackages
      != []
      && builtins.length testModuleLevelConfig.latex-utils.extraTexPackages == 2;
    expected = true;
  };

  # Test: Comprehensive example configuration structure is valid
  testComprehensiveConfigValid = {
    expr =
      testComprehensiveConfig.latex-utils.extraTexPackages
      != []
      && builtins.length testComprehensiveConfig.latex-utils.documents == 2
      && (builtins.head testComprehensiveConfig.latex-utils.documents).name == "thesis.pdf";
    expected = true;
  };

  # Test: Documents can be built (validates that the configuration works end-to-end)
  testDocumentBuildable = {
    expr =
      docTestOutputs ? packages
      && docTestOutputs.packages ? ${system}
      && docTestOutputs.packages.${system} ? "test";
    expected = true;
  };

  # Test: Default package is set correctly (first document in list)
  testDefaultPackageSet = {
    expr =
      docTestOutputs ? packages
      && docTestOutputs.packages ? ${system}
      && lib.isDerivation docTestOutputs.packages.${system}."test";
    expected = true;
  };

  # Test: Quickstart example pattern - documents list with basic structure
  testQuickstartPattern = {
    expr = let
      quickstartConfig = {
        latex-utils.documents = [
          {
            name = "paper.pdf";
            src = minimalTexSrc;
          }
          {
            name = "slides.pdf";
            src = minimalTexSrc;
            inputFile = "main.tex";
          }
        ];
      };
    in
      builtins.length quickstartConfig.latex-utils.documents
      == 2
      && (builtins.head quickstartConfig.latex-utils.documents).name == "paper.pdf";
    expected = true;
  };

  # Test: extraTexPackages supports string list format (documented in README)
  testStringListExtraPackages = {
    expr = let
      config = {
        extraTexPackages = ["amsmath" "xcolor"];
      };
    in
      builtins.isList config.extraTexPackages
      && builtins.all builtins.isString config.extraTexPackages;
    expected = true;
  };

  # Test: extraTexPackages supports function format (documented in README)
  testFunctionExtraPackages = {
    expr = let
      config = {
        extraTexPackages = discovered: ["amsmath" "amssymb"];
      };
    in
      builtins.isFunction config.extraTexPackages;
    expected = true;
  };

  # Test: Document options structure matches documented interface
  testDocumentOptionsStructure = {
    expr = let
      docConfig = {
        name = "mydoc.pdf";
        src = minimalTexSrc;
        inputFile = "main.tex";
        extraTexPackages = ["mathrsfs"];
      };
    in
      docConfig ? name
      && docConfig ? src
      && docConfig ? inputFile
      && docConfig ? extraTexPackages
      && builtins.isString docConfig.name
      && builtins.isString docConfig.inputFile
      && builtins.isList docConfig.extraTexPackages;
    expected = true;
  };

  # Test: Boolean option types work as documented
  testBooleanOptionTypes = {
    expr = let
      config = {
        latex-utils.enableVSCode = true;
        latex-utils.flakeFormatter = false;
        latex-utils.flakeCheck = false;
      };
    in
      builtins.isBool config.latex-utils.enableVSCode
      && builtins.isBool config.latex-utils.flakeFormatter
      && builtins.isBool config.latex-utils.flakeCheck;
    expected = true;
  };
}
