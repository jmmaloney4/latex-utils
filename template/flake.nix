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
      imports = [flakeInputs.flake-parts.flakeModules.easySetup];
      perSystem = {
        config,
        pkgs,
        ...
      }: {
        imports = [inputs.latex-utils.modules.flake.latex-utils];
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
        # Use the turn-key VS Code shell:
        devShells.default = config.devShells.latex-utils;
        # Or compose your own shell fragments:
        # devShells.myCustom = pkgs.mkShell {
        #   inputsFrom = [
        #     config.latex-utils.build.unifiedTexShell
        #     config.latex-utils.build.vscodeSettingsShell # Optional: links VS Code settings
        #   ];
        #   buildInputs = [ /* your extra tools */ ];
        # };
        # To disable VS Code integration:
        # latex-utils.enableVSCode = false;
      };
    };
}
