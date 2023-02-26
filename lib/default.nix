{ pkgs
}:
{
  mkLatexDocument = import ./mkLatexDocument.nix { inherit pkgs; };
}
