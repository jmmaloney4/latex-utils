{
  pkgs,
  lib,
  ...
}:
with pkgs.lib.attrsets;
with pkgs.lib;
with pkgs.lib.debug; 
let
  processDirectory = rootPath: extensions: let
    readDir = builtins.readDir rootPath;

    # paths = traceVal (mapAttrs (  name: type: rootPath + "/${name}") readDir);
    directories = attrNames (filterAttrs (name: type: type == "directory") readDir);
    files = attrNames (filterAttrs (name: type: type == "regular") readDir);
    filesWithExtensions = filter (name: lists.any (ext: strings.hasSuffix ext name) extensions) files;
    fullPaths = map (name: rootPath + "/${name}") filesWithExtensions;
    recuriveFiles = builtins.concatLists (map (name: processDirectory (rootPath + "/${name}") extensions) directories);
  in
    filesWithExtensions ++ recuriveFiles;
in
  {
    basePath,
    extensions ? [".tex" ".cls"],
  }:
    processDirectory basePath extensions
