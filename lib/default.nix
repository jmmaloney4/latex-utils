{ pkgs
}: let
lib = {
  findLatexFiles = import ./findLatexFiles.nix { inherit pkgs lib; };
  findLatexPackages = import ./findLatexPackages.nix { inherit pkgs lib; };
  mkLatexDocument = import ./mkLatexDocument.nix { inherit pkgs lib; };
};
in lib
