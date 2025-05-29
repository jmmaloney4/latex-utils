{
  pkgs,
  fonts,
}: let
  fontPaths = builtins.concatStringsSep " " (map (f: "${f}/share/fonts") fonts);
  fontconfig = pkgs.fontconfig;
  getExe = pkgs.lib.getExe;
  getExe' = pkgs.lib.getExe';
in
  pkgs.stdenvNoCC.mkDerivation {
    name = "fontconfig-cache";
    nativeBuildInputs = [fontconfig] ++ fonts;
    dontUnpack = true;
    buildPhase = ''
      export FONTCONFIG_FILE="${fontconfig.out}/etc/fonts/fonts.conf"
      export FONTCONFIG_PATH="${fontconfig.out}/etc/fonts"
      export XDG_CACHE_HOME=$(pwd)/.cache
      export FONTCONFIG_CACHE_DIR=$XDG_CACHE_HOME/fontconfig
      mkdir -p $FONTCONFIG_CACHE_DIR
      ${getExe' fontconfig "fc-cache"} -fv ${fontPaths}
    '';
    installPhase = ''
      mkdir -p $out
      cp -r $XDG_CACHE_HOME/fontconfig $out/
    '';
  }
