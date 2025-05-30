# --------------------------------------------------------------------------------------
# Regex Compatibility in Nix (builtins.match)
# --------------------------------------------------------------------------------------
# NOTE: Nix's builtins.match uses ECMAScript (std::regex), but platform differences
# (libstdc++ vs libc++) and Nix string escaping rules make regex portability tricky.
# Regexes that work elsewhere may fail in Nix.
#
# Key guidelines for writing portable regexes in Nix:
#
# 1. **Curly Braces `{}`**
#    - To match literal `{` or `}` use character classes: `[{]` for `{`, `[}]` for `}`.
#    - Avoid using `\{` or `\}`; these may cause errors, especially on Linux (libstdc++).
#    - Example: `''foo[{]bar[}]''` matches `foo{bar}`.
#
# 2. **Square Brackets `[]`**
#    - To match a literal `[`, use `[[]` inside a character class.
#    - To match a literal `]`, use `[]]` inside a character class.
#    - Example: `''foo[[]bar[]]baz''` matches `foo[bar]baz`.
#
# 3. **Backslashes and Escaping**
#    - In Nix, backslashes in double-quoted strings must be doubled (e.g., `\\d` for `\d`).
#    - Prefer using Nix's multi-line strings (`'' ... ''`) to avoid excessive escaping.
#
# 4. **Parentheses for Capturing Groups**
#    - Use `()` for capturing groups as usual, but ensure all special characters inside are properly escaped.
#
# 5. **Non-Greedy Quantifiers**
#    - ECMAScript regexes support non-greedy quantifiers (e.g., `*?`, `+?`), but always test on both Linux and macOS.
#
# 6. **General Tips**
#    - Always test your regex on both Linux and macOS if possible.
#    - Use `nix repl` or a minimal Nix file to test regexes before committing.
#    - If you get an "invalid regular expression" error, check for improper escaping of `{`, `}`, `[`, `]`, or backslashes.
#    - The regex engine is ECMAScript (std::regex), but platform quirks exist.
#
# Example (matching \usepackage with optional [options] and {packages}):
#   ''^.*\\usepackage([[][^]]*[]])?[ ]*[{]([^}]*)[}].*$''
#
# This file follows these guidelines for all regexes. Please do the same for future edits!
#
# References:
# - https://discourse.nixos.org/t/nix-regex-match/794
# - https://github.com/NixOS/nix/issues/3063
# --------------------------------------------------------------------------------------
{
  pkgs,
  lib,
  ...
}: let
in
  {fileContents}:
    with pkgs.lib.attrsets;
    with pkgs.lib.strings; let
      buildCTANRegex = n: let
        prefix = ''^\\usepackage.*[{](.*)[}].*% CTAN: '';
        packageName = ''(.*)'';
        suffix = ''.*$'';

        reps = pkgs.lib.lists.replicate n packageName;
        str = pkgs.lib.strings.concatStringsSep " " reps;
      in
        prefix + str + suffix;

      processLine = line: n: let
        regex = buildCTANRegex n;
        matches = builtins.match regex line;
        next =
          if (matches != null)
          then (processLine line (n + 1))
          else null;
      in
        if (next != null)
        then next
        else matches;

      # Extracts package names from lines like:
      #   \usepackage{foo, bar}
      #   \usepackage[options]{foo, bar}
      # Returns a list of trimmed package names.
      lineToPackageNames = (
        line: let
          m = builtins.match ''^.*\\usepackage([[][^]]*[]])?[ ]*[{]([^}]*)[}].*$'' line;
        in
          if m == null
          then []
          else
            map (pkg: pkgs.lib.strings.trim pkg)
            (pkgs.lib.strings.splitString "," (builtins.elemAt m 1))
      );

      lines = splitString "\n" fileContents;
      processedLines = builtins.filter (x: x != null) (builtins.map lineToPackageNames lines);
      packageNames = builtins.concatLists processedLines;
      texPackages = filterAttrs (y: x: x != null) (genAttrs packageNames (name: attrByPath [name] null pkgs.texlive));
    in
      texPackages
