{
  pkgs,
  lib,
  ...
}:
with pkgs.lib.attrsets;
with pkgs.lib;
with pkgs.lib.debug; let
  processDirectory = rootPath: extensions: let
    readDir =
      builtins.tryEval (builtins.readDir rootPath);
    directories =
      if readDir.success
      then attrNames (filterAttrs (name: type: type == "directory") readDir.value)
      else [];
    files =
      if readDir.success
      then attrNames (filterAttrs (name: type: type == "regular") readDir.value)
      else [];
    filesWithExtensions = filter (name: lists.any (ext: strings.hasSuffix ext name) extensions) files;
    fullPaths = map (name: rootPath + "/${name}") filesWithExtensions;
    recuriveFiles = builtins.concatLists (map (name: processDirectory (rootPath + "/${name}") extensions) directories);
  in
    fullPaths ++ recuriveFiles;
in
  {
    basePath,
    extensions ? [".tex" ".cls"],
  }:
    pkgs.lib.lists.unique (processDirectory basePath extensions)
