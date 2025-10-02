{
  description = "Easily compile latex documents with nix flakes.";

  inputs = {
    nixpkgs.url = github:NixOS/nixpkgs/nixos-unstable;
    flake-parts.url = github:hercules-ci/flake-parts;
    systems.url = "github:nix-systems/default";
    nix-unit.url = github:nix-community/nix-unit;
    treefmt-nix.url = "github:numtide/treefmt-nix";
    mission-control.url = "github:Platonic-Systems/mission-control";
    flake-root.url = "github:srid/flake-root";
    git-hooks-nix.url = "github:cachix/git-hooks.nix";
    mkdocs-flake.url = "github:applicative-systems/mkdocs-flake";
  };

  outputs = flakeInputs @ {
    flake-parts,
    nix-unit,
    systems,
    ...
  }:
    flake-parts.lib.mkFlake {inputs = flakeInputs;} {
      systems = import systems;
      imports = [
        flakeInputs.nix-unit.modules.flake.default
        flakeInputs.treefmt-nix.flakeModule
        flakeInputs.mission-control.flakeModule
        flakeInputs.flake-root.flakeModule
        flakeInputs.git-hooks-nix.flakeModule
        flakeInputs.flake-parts.flakeModules.modules
        flakeInputs.mkdocs-flake.flakeModule
        # Note: ./modules/latex-utils.nix is auto-discovered by flake-parts.modules
        # and published as outputs.modules.flake.latex-utils
      ];
      perSystem = {
        config,
        pkgs,
        lib,
        system,
        inputs,
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
              devShellLatexUtils = import ./tests/devShellLatexUtils.nix;
              normalizeExtraTexPackages = import ./tests/normalizeExtraTexPackages.nix {
                inherit pkgs lib;
              };
              devShellFragments = import ./tests/devShellFragments.nix;
              documentsPackage = import ./tests/documentsPackage.nix {
                inherit pkgs lib system inputs;
              };
              # Documentation validation tests
              documentationValidation = import ./tests/documentationValidation.nix;
              accessPathValidation = import ./tests/accessPathValidation.nix;
              packageReferenceValidation = import ./tests/packageReferenceValidation.nix;
              documentationIntegrationCheck = import ./tests/documentationIntegrationCheck.nix;
              latexmkEngineAndOutputs = import ./tests/latexmkEngineAndOutputs.nix {
                inherit pkgs lib system inputs;
              };
            }
            // (import ./tests/testModuleLevel.nix {inherit pkgs lib;});
        };
        treefmt = {
          config = {
            package = pkgs.treefmt;
            programs.alejandra.enable = true;
            programs.latexindent.enable = true;
          };
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
        pre-commit = {
          check.enable = true;
          settings = {
            hooks.treefmt = {
              enable = true;
              package = config.treefmt.build.wrapper;
            };
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
