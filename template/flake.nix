{
  inputs = {
    nixpkgs.url = github:NixOS/nixpkgs/nixos-unstable;
    flake-parts.url = github:hercules-ci/flake-parts;
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
      imports = [inputs.latex-utils.modules.latex-utils];
      perSystem = {
        config,
        pkgs,
        ...
      }: {
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
        devShells.default = config.latex-utils.devShells.full;
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
