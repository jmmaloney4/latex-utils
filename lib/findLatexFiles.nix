{
  pkgs,
  lib,
  ...
}:
/*
Function: findLatexFiles

Description:
  Recursively finds all files with specified extensions (defaulting to .tex and .cls)
  within a given base path. It returns a de-duplicated list of absolute paths
  to the found files.

Parameters:
  basePath (string, required): The absolute or relative path to the directory to search.
  extensions (list of strings, optional, default: [".tex" ".cls"]):
    A list of file extensions to search for (e.g., [".tex", ".bib", ".cls"]).

Returns:
  list of strings: A list of unique absolute paths to the LaTeX files found.

Example:
  findLatexFiles {
    basePath = ./my-latex-project;
    extensions = [ ".tex" ".sty" ];
  }
  => [ "/path/to/my-latex-project/main.tex", "/path/to/my-latex-project/styles/custom.sty", ... ]
*/
with pkgs.lib.attrsets;
with pkgs.lib;
with pkgs.lib.debug; let
  processDirectory = rootPath: extensions: let
    readDir =
      builtins.tryEval (builtins.readDir rootPath);
    warnIfFile =
      if !readDir.success && builtins.pathExists rootPath && !(builtins.tryEval (builtins.readDir (builtins.dirOf rootPath))).success
      then
        builtins.trace "[findLatexFiles WARNING] basePath '${rootPath}' is not a directory. This will fail on Darwin."
        null
      else null;
    _ = warnIfFile;
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
    recursiveFiles = builtins.concatLists (map (name: processDirectory (rootPath + "/${name}") extensions) directories);
  in
    fullPaths ++ recursiveFiles;
in
  {
    basePath,
    extensions ? [".tex" ".cls"],
  }:
    pkgs.lib.lists.unique (processDirectory basePath extensions)
