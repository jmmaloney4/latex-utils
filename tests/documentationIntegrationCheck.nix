{
  pkgs,
  lib,
  system,
  inputs,
  ...
}: let
  # Helper to create minimal TeX source with different packages
  createTexSrc = packages: content:
    pkgs.writeTextDir "main.tex" ''
      \documentclass{article}
      ${lib.concatMapStrings (pkg: "\\usepackage{${pkg}}\n") packages}
      \begin{document}
      ${content}
      \end{document}
    '';

  # Test the quickstart example from README
  quickstartExample = {
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

          # Configure latex-utils options at module level (NOT in perSystem)
          latex-utils.documents = [
            {
              name = "paper.pdf";
              src = createTexSrc ["amsmath"] "Hello, world! $E = mc^2$";
            }
            {
              name = "slides.pdf";
              src = createTexSrc ["amsmath" "xcolor"] "\\textcolor{red}{Hello!}";
              inputFile = "main.tex";
            }
          ];

          perSystem = {
            config,
            pkgs,
            system,
            ...
          }: {
            # Use the ready-to-go devShell with VSCode integration
            devShells.default = config.devShells.latex-utils;
          };
        };
    };
    outputsArgs = {
      self = {};
      nixpkgs = inputs.nixpkgs;
      flake-parts = inputs.flake-parts;
    };
  };

  # Test the comprehensive example from docs/user/comprehensive-example.nix
  comprehensiveExample = {
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

          # Module-level configuration (NOT in perSystem)
          latex-utils.extraTexPackages = ["amsmath" "geometry" "hyperref"];

          latex-utils.documents = [
            {
              name = "thesis.pdf";
              src = createTexSrc ["amsmath" "geometry"] "Thesis content";
            }
            {
              name = "poster.pdf";
              src = createTexSrc ["tikz"] "Poster content";
              inputFile = "main.tex";
              extraTexPackages = ["tikz"];
            }
          ];

          perSystem = {
            config,
            pkgs,
            system,
            lib,
            ...
          }: {
            # Use the unified VSCode dev shell provided by latex-utils
            devShells.default = config.devShells.latex-utils;

            # Custom composition example
            devShells.custom = pkgs.mkShell {
              inputsFrom = [config.latex-utils.unifiedTexShell];
              buildInputs = [pkgs.git];
            };
          };
        };
    };
    outputsArgs = {
      self = {};
      nixpkgs = inputs.nixpkgs;
      flake-parts = inputs.flake-parts;
    };
  };

  # Test the template example
  templateExample = {
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
              name = "document.pdf";
              src = createTexSrc ["amsmath"] "Template example";
            }
          ];

          perSystem = {config, ...}: {
            devShells.default = config.devShells.latex-utils;
          };
        };
    };
    outputsArgs = {
      self = {};
      nixpkgs = inputs.nixpkgs;
      flake-parts = inputs.flake-parts;
    };
  };

  # Helper to test that a flake example works
  testExample = name: example:
    import ./test-flake-helpers.nix {
      flakeDef = example.flakeDef;
      outputsArgs = example.outputsArgs;
    };

  # Test all examples
  quickstartOutput = testExample "quickstart" quickstartExample;
  comprehensiveOutput = testExample "comprehensive" comprehensiveExample;
  templateOutput = testExample "template" templateExample;
in {
  # Test: Quickstart example produces expected outputs
  testQuickstartExampleWorks = {
    expr =
      quickstartOutput ? packages
      && quickstartOutput.packages ? ${system}
      && quickstartOutput.packages.${system} ? "paper"
      && quickstartOutput.packages.${system} ? "slides"
      && quickstartOutput.packages.${system} ? "default"
      && quickstartOutput ? devShells
      && quickstartOutput.devShells ? ${system}
      && quickstartOutput.devShells.${system} ? "default";
    expected = true;
  };

  # Test: Comprehensive example produces expected outputs
  testComprehensiveExampleWorks = {
    expr =
      comprehensiveOutput ? packages
      && comprehensiveOutput.packages ? ${system}
      && comprehensiveOutput.packages.${system} ? "thesis"
      && comprehensiveOutput.packages.${system} ? "poster"
      && comprehensiveOutput ? devShells
      && comprehensiveOutput.devShells ? ${system}
      && comprehensiveOutput.devShells.${system} ? "default"
      && comprehensiveOutput.devShells.${system} ? "custom";
    expected = true;
  };

  # Test: Template example works
  testTemplateExampleWorks = {
    expr =
      templateOutput ? packages
      && templateOutput.packages ? ${system}
      && templateOutput.packages.${system} ? "document"
      && templateOutput ? devShells
      && templateOutput.devShells ? ${system}
      && templateOutput.devShells.${system} ? "default";
    expected = true;
  };

  # Test: Shell fragments are accessible in all examples
  testShellFragmentsAccessible = {
    expr =
      quickstartOutput ? latex-utils
      && quickstartOutput.latex-utils ? ${system}
      && quickstartOutput.latex-utils.${system} ? unifiedTexShell
      && quickstartOutput.latex-utils.${system} ? vscodeShell
      && comprehensiveOutput.latex-utils.${system} ? unifiedTexShell
      && comprehensiveOutput.latex-utils.${system} ? vscodeShell
      && templateOutput.latex-utils.${system} ? unifiedTexShell
      && templateOutput.latex-utils.${system} ? vscodeShell;
    expected = true;
  };

  # Test: All shell components are derivations (can be used with inputsFrom)
  testShellComponentsAreDerivations = {
    expr =
      lib.isDerivation quickstartOutput.latex-utils.${system}.unifiedTexShell
      && lib.isDerivation quickstartOutput.latex-utils.${system}.vscodeShell
      && lib.isDerivation quickstartOutput.devShells.${system}."latex-utils"
      && lib.isDerivation comprehensiveOutput.devShells.${system}."default"
      && lib.isDerivation comprehensiveOutput.devShells.${system}."custom";
    expected = true;
  };

  # Test: Document packages are derivations (can be built)
  testDocumentPackagesAreDerivations = {
    expr =
      lib.isDerivation quickstartOutput.packages.${system}."paper"
      && lib.isDerivation quickstartOutput.packages.${system}."slides"
      && lib.isDerivation comprehensiveOutput.packages.${system}."thesis"
      && lib.isDerivation comprehensiveOutput.packages.${system}."poster"
      && lib.isDerivation templateOutput.packages.${system}."document";
    expected = true;
  };

  # Test: Default packages are set correctly (first document)
  testDefaultPackagesCorrect = {
    expr =
      quickstartOutput.packages.${system}."default"
      == quickstartOutput.packages.${system}."paper"
      && comprehensiveOutput.packages.${system}."default" == comprehensiveOutput.packages.${system}."thesis"
      && templateOutput.packages.${system}."default" == templateOutput.packages.${system}."document";
    expected = true;
  };

  # Test: VSCode integration is enabled by default
  testVscodeIntegrationEnabled = {
    expr =
      # VSCode shells should exist and be different from unified shells
      quickstartOutput.latex-utils.${system}.vscodeShell
      != quickstartOutput.latex-utils.${system}.unifiedTexShell
      && comprehensiveOutput.latex-utils.${system}.vscodeShell != comprehensiveOutput.latex-utils.${system}.unifiedTexShell;
    expected = true;
  };

  # Test: Module-level packages work as documented
  testModuleLevelPackagesWork = {
    expr =
      # Comprehensive example has module-level packages and should work
      comprehensiveOutput ? packages
      && comprehensiveOutput.packages.${system} ? "thesis"
      && comprehensiveOutput.packages.${system} ? "poster";
    expected = true;
  };
}
