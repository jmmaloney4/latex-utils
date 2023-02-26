{ pkgs
}: let
lib = {
  findLatexPackages = import ./findLatexPackages.nix { inherit pkgs lib; };
  mkLatexDocument = import ./mkLatexDocument.nix { inherit pkgs lib; };
};
in lib
