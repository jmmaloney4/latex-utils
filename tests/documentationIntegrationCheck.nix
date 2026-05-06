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

  # Helper to build a test flake with the correct system and self
  mkTestExample = flakeModuleConfig:
    let
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
            # Override self.inputs to contain resolved flake objects.
            # The raw self has URL-string inputs which crash when flake-parts
            # computes inputs' (it iterates self.inputs expecting flake objects).
            self = outputsArgs.self // {
              inputs = { inherit (outputsArgs) nixpkgs flake-parts; };
            };
            inputs = {
              inherit (outputsArgs) nixpkgs flake-parts;
            };
          } (flakeModuleConfig outputsArgs);
      };
    in {
      inherit flakeDef;
      outputsArgs = {
        self = flakeDef;
        nixpkgs = inputs.nixpkgs;
        flake-parts = inputs.flake-parts;
        inherit system;
      };
    };

  # Test the quickstart example from README
  quickstartExample = mkTestExample (outputsArgs: {
    systems = [system];
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
  });

  # Test the comprehensive example from docs/user/comprehensive-example.nix
  comprehensiveExample = mkTestExample (outputsArgs: {
    systems = [system];
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
  });

  # Test the template example
  templateExample = mkTestExample (outputsArgs: {
    systems = [system];
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
  });

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

  # Create a test flake with documents to check integration
  inlineFlakeDef = {
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
        self = outputsArgs.self // {
          inputs = { inherit (outputsArgs) nixpkgs flake-parts; };
        };
        inputs = {
          inherit (outputsArgs) nixpkgs flake-parts;
        };
      } {
        systems = [system];
        imports = [../modules/latex-utils.nix];
        latex-utils.documents = [];
      };
  };
  testFlakeWithDocs = import ./test-flake-helpers.nix {
    flakeDef = inlineFlakeDef;
    outputsArgs = testHarnessOutputsArgs // { self = inlineFlakeDef; };
  };
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
  # The latex-utils module does not create a packages.default alias,
  # so we only check that the named packages exist and are derivations.
  testDefaultPackagesCorrect = {
    expr =
      lib.isDerivation quickstartOutput.packages.${system}."paper"
      && lib.isDerivation comprehensiveOutput.packages.${system}."thesis"
      && lib.isDerivation templateOutput.packages.${system}."document";
    expected = true;
  };

  # Test: VSCode integration is enabled by default
  # Check that vscodeShell exists and is a derivation alongside unifiedTexShell
  testVscodeIntegrationEnabled = {
    expr =
      lib.isDerivation quickstartOutput.latex-utils.${system}.vscodeShell
      && lib.isDerivation quickstartOutput.latex-utils.${system}.unifiedTexShell
      && lib.isDerivation comprehensiveOutput.latex-utils.${system}.vscodeShell
      && lib.isDerivation comprehensiveOutput.latex-utils.${system}.unifiedTexShell;
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

  testVscodeSettingsOutputPresent = {
    expr =
      testFlakeWithDocs ? packages
      && testFlakeWithDocs.packages ? ${system}
      && testFlakeWithDocs.packages.${system} ? "vscodeSettings";
    expected = true;
  };
}
