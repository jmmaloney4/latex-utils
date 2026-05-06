{
  description = "Easily compile latex documents with nix flakes.";

  inputs = {
    nixpkgs.follows = "jackpkgs/nixpkgs";

    jackpkgs = {
      url = "github:jmmaloney4/jackpkgs";
    };
    flake-parts.follows = "jackpkgs/flake-parts";
    systems.follows = "jackpkgs/systems";
    nix-unit.follows = "jackpkgs/nix-unit";
    flake-root.follows = "jackpkgs/flake-root";
    mission-control.url = "github:Platonic-Systems/mission-control";
    mkdocs-flake.url = "github:applicative-systems/mkdocs-flake";
  };

  outputs = flakeInputs @ {
    flake-parts,
    nix-unit,
    jackpkgs,
    systems,
    ...
  }:
    flake-parts.lib.mkFlake {inputs = flakeInputs;} {
      systems = import systems;
      imports = [
        flakeInputs.nix-unit.modules.flake.default
        flakeInputs.mission-control.flakeModule
        flakeInputs.flake-parts.flakeModules.modules
        flakeInputs.mkdocs-flake.flakeModule

        # jackpkgs modules (all -- unused modules like python/nodejs/pulumi are
        # no-ops unless explicitly enabled)
        jackpkgs.flakeModules.default

        # Note: ./modules/latex-utils.nix is auto-discovered by flake-parts.modules
        # and published as outputs.modules.flake.latex-utils
      ];
      jackpkgs.pulumi.enable = false;
      perSystem = {
        config,
        pkgs,
        lib,
        system,
        inputs',
        self',
        ...
      }: {
        flake-root = {
          projectRootFile = "flake.nix";
        };
        documentation.mkdocs-root = ./.;
        nix-unit = {
          allowNetwork = true;
          inputs = {
            inherit (flakeInputs) nixpkgs flake-parts;
            latex-utils = flakeInputs.self;
          };
          tests =
            {
              findLatexPackages = import ./tests/findLatexPackages.nix {
                inherit pkgs lib;
                findLatexPackages = import ./lib/findLatexPackages.nix {inherit pkgs lib;};
              };
              extraTexPackages = import ./tests/extraTexPackages.nix {
                inherit pkgs lib;
              };
              unifiedTexLive = import ./tests/unifiedTexLive.nix {
                inherit pkgs lib;
              };
              documentLevelPackages = import ./tests/documentLevelPackages.nix {
                inherit pkgs lib;
              };
              devShellLatexUtils = import ./tests/devShellLatexUtils.nix {
                inherit pkgs lib system;
                inputs = flakeInputs;
              };
              normalizeExtraTexPackages = import ./tests/normalizeExtraTexPackages.nix {
                inherit pkgs lib;
              };
              devShellFragments = import ./tests/devShellFragments.nix {
                inherit pkgs lib system;
                inputs = flakeInputs;
              };
              documentsPackage = import ./tests/documentsPackage.nix {
                inherit pkgs lib system;
                inputs = flakeInputs;
              };
              # Documentation validation tests
              documentationValidation = import ./tests/documentationValidation.nix {
                inherit pkgs lib system;
                inputs = flakeInputs;
              };
              accessPathValidation = import ./tests/accessPathValidation.nix {
                inherit pkgs lib system;
                inputs = flakeInputs;
              };
              packageReferenceValidation = import ./tests/packageReferenceValidation.nix {
                inherit pkgs lib system;
                inputs = flakeInputs;
              };
              documentationIntegrationCheck = import ./tests/documentationIntegrationCheck.nix {
                inherit pkgs lib system;
                inputs = flakeInputs;
              };
              latexmkEngineAndOutputs = import ./tests/latexmkEngineAndOutputs.nix {
                inherit pkgs lib system;
                inputs = flakeInputs;
              };
            }
            // (import ./tests/testModuleLevel.nix {inherit pkgs lib;});
        };
        # treefmt config is managed by jackpkgs.fmt module
        # alejandra and latexindent are enabled by default
        jackpkgs.fmt = {
          excludes = [
            "template/**"
          ];
          mdformat.validate = false; # LaTeX markdown in docs
        };
        mission-control = {
          scripts = {
            fmt = {
              description = "Format all Nix files";
              exec = "${lib.getExe pkgs.alejandra} .";
              category = "Tools";
            };
          };
        };
        devShells = {
          default = pkgs.mkShell {
            inputsFrom = [
              config.mission-control.devShell
              config.pre-commit.devShell
              config.treefmt.build.devShell
            ];
          };
        };
      };
      # For backward compatibility, as per ADR-007
      flake = {
        flakeModule = import ./modules/latex-utils.nix;
        modules.flake.latex-utils = ./modules/latex-utils.nix;
      };
    };
}
