{
  description = "Easily compile latex documents with nix flakes.";

  inputs = {
    nixpkgs.url = github:NixOS/nixpkgs/nixos-unstable;
    flake-parts.url = github:hercules-ci/flake-parts;
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" ];
      imports = [ ./modules/latex-utils.nix ];
    }
    // {
      flakeModule = import ./modules/latex-utils.nix;
      modules.latex-utils = import ./modules/latex-utils.nix;
    };
}
