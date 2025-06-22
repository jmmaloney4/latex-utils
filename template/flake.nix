{
  description = "A LaTeX document project using latex-utils";

  inputs = {
    # Pin the version of nixpkgs to ensure reproducibility
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    latex-utils = {
      url = "github:jmmaloney4/latex-utils";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };
  };

  outputs = inputs @ {
    flake-parts,
    latex-utils,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux"];
      imports = [
        inputs.latex-utils.modules.flake.latex-utils
      ];

      # Configure latex-utils at module level (NOT in perSystem)
      latex-utils.documents = [
        {
          name = "mydocument.pdf";
          src = ./.;
          # inputFile = "main.tex";
          # extraTexPackages = [ "amscls" "beamer" ];
          # Or, using derivations:
          # extraTexPackages = [ pkgs.texlive.amscls pkgs.texlive.beamer ];
        }
      ];

      perSystem = {
        config,
        pkgs,
        ...
      }: {
        # Use the turn-key VS Code shell:
        devShells.default = config.devShells.latex-utils;
        # Or compose your own shell fragments:
        # devShells.myCustom = pkgs.mkShell {
        #   inputsFrom = [
        #     config.latex-utils.unifiedTexShell
        #     config.latex-utils.vscodeShell # Optional: adds VS Code integration
        #   ];
        #   buildInputs = [ /* your extra tools */ ];
        # };
        # To disable VS Code integration (at module level):
        # latex-utils.enableVSCode = false;
      };
    };
}
