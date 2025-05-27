{ config, lib, pkgs, ... }:
{
  options.latex-utils.enable = lib.mkEnableOption "Enable latex-utils outputs (mkLatexPdfDocument)";

  config = lib.mkIf config.latex-utils.enable {
    perSystem = { pkgs, ... }: {
      packages.mkLatexPdfDocument = pkgs.callPackage ../lib/mkLatexPdfDocument.nix { lib = import ../lib/default.nix { pkgs = pkgs; }; };
      # Optionally, you can add more utilities here
    };
    # Export mkLatexPdfDocument as a top-level function for module import
    mkLatexPdfDocument = pkgs.callPackage ../lib/mkLatexPdfDocument.nix { lib = import ../lib/default.nix { pkgs = pkgs; }; };
  };
} 