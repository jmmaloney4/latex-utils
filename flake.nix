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
  };

  outputs = inputs @ {
    flake-parts,
    nix-unit,
    systems,
    ...
  }:
    flake-parts.lib.mkFlake {inputs = inputs;} {
      systems = import systems;
      imports = [
        inputs.nix-unit.modules.flake.default
        inputs.treefmt-nix.flakeModule
        inputs.mission-control.flakeModule
        inputs.flake-root.flakeModule
        inputs.git-hooks-nix.flakeModule
      ];
      perSystem = {
        config,
        pkgs,
        lib,
        system,
        ...
      }: {
        flake-root = {
          projectRootFile = "flake.nix";
        };
        nix-unit = {
          allowNetwork = true;
          tests = {
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
            # Commented out flake-parts module tests - focus on library tests first
            # devShellLatexUtils = import ./tests/devShellLatexUtils.nix {
            #   inherit pkgs lib;
            #   mainFlakeResolvedInputs = inputs;
            # };
            normalizeExtraTexPackages = import ./tests/normalizeExtraTexPackages.nix {
              inherit pkgs lib;
            };
            # devShellFragments = import ./tests/devShellFragments.nix {
            #   inherit pkgs lib;
            #   mainFlakeResolvedInputs = inputs;
            # };
          };
          # Commented out module-level tests - focus on library tests first
          # // (import ./tests/testModuleLevel.nix {inherit pkgs lib;});
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
      flake = {
        flakeModule = import ./modules/latex-utils.nix;
        flakeModules.latex-utils = import ./modules/latex-utils.nix;
      };
    };
}
