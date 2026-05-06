# Library Reference: latex-utils

This document provides detailed documentation for the utility functions in the `lib/` directory of latex-utils.

______________________________________________________________________

## `findLatexFiles`

**Summary:**
Recursively finds all LaTeX source files (by default, `.tex` and `.cls`) in a directory tree.

**Arguments:**

- `basePath` (path): The root directory to search.
- `extensions` (list of strings, optional): File extensions to include (default: `[".tex", ".cls"]`).

**Return:**

- List of file paths (strings) matching the given extensions.

**Example:**

```nix
findLatexFiles { basePath = ./my-paper; }
# => [ ./my-paper/main.tex ./my-paper/custom.cls ... ]
```

**Notes:**

- Uses Nix builtins to traverse directories recursively.

______________________________________________________________________

## `findLatexPackages`

**Summary:**
Parses LaTeX source file contents to extract required TeX Live package names from `\usepackage` lines.

**Arguments:**

- `fileContents` (string): The contents of a LaTeX file.

**Return:**

- Attribute set mapping package names to their corresponding `pkgs.texlive` derivations (if available).

**Example:**

```nix
findLatexPackages { fileContents = ''
  \usepackage{amsmath}
  \usepackage{xcolor}
''; }
# => { amsmath = pkgs.texlive.amsmath; xcolor = pkgs.texlive.xcolor; }
```

**Notes:**

- Handles multiple packages per line and ignores commented lines.
- See `tests/findLatexPackages.nix` for more examples and edge cases.

______________________________________________________________________

## `mkLatexPdfDocument`

**Summary:**
Builds a LaTeX document as a Nix derivation, automatically including required and extra TeX Live packages, and prebuilding the fontconfig cache for reliable font discovery.

**Arguments:**

- `name` (string): Name of the output PDF (should end with `.pdf`).
- `src` (path): Source directory containing the LaTeX files.
- `inputFile` (string, optional): Main `.tex` file to build (default: `main.tex`).
- `extraTexPackages` (list of strings, optional): Extra TeX Live packages to include.
- `scheme` (derivation, optional): TeX Live scheme to use (default: `pkgs.texlive.scheme-basic`).
- Other advanced arguments: `workingDirectory`, `outputPath`, `texPackages`, `silent`, `nativeBuildInputs`, `phases`, `buildPhase`, `installPhase`, `stdenv`.

**Return:**

- A Nix derivation that builds the specified PDF.

**Example:**

```nix
mkLatexPdfDocument {
  name = "my-paper.pdf";
  src = ./my-paper;
  inputFile = "main.tex";
  extraTexPackages = [ "xcolor" ];
}
```

**Notes:**

- Automatically scans sources for required packages using `findLatexFiles` and `findLatexPackages`.
- Prebuilds the fontconfig cache using `mkFontconfigCache`.
- See `tests/extraTexPackages.nix` for usage examples.

______________________________________________________________________

## `mkFontconfigCache`

**Summary:**
Prebuilds a fontconfig cache for use in sandboxed LaTeX builds, ensuring reliable font discovery for LuaLaTeX and XeLaTeX.

**Arguments:**

- `pkgs` (attribute set): Nixpkgs package set.
- `fonts` (list of derivations): List of font derivations to include in the cache.

**Return:**

- A Nix derivation containing the prebuilt fontconfig cache.

**Example:**

```nix
mkFontconfigCache {
  pkgs = import <nixpkgs> {};
  fonts = [ pkgs.texlive.scheme-basic ];
}
```

**Notes:**

- Used internally by `mkLatexPdfDocument`.
- Ensures reproducible and fast font discovery in Nix builds.

______________________________________________________________________

## `normalizeExtraTexPackages`

**Summary:**
Normalizes different input formats for `extraTexPackages` to a consistent attrset of derivations.

**Arguments:**

- `extraTexPackages` (list or function): The extraTexPackages input.
  - List of package name strings (e.g., `["mathrsfs" "xcolor"]`)
  - List of derivations (e.g., `[pkgs.texlive.mathrsfs pkgs.texlive.xcolor]`)
  - Function returning a list of derivations (e.g., `discovered: if builtins.hasAttr "tikz" discovered then [pkgs.texlive.pgfplots] else []`)
- `discoveredPackages` (attrset): Attrset of discovered packages (used when `extraTexPackages` is a function).

**Return:**

- Attribute set mapping package names to their corresponding derivations.

**Example Usage:**

```nix
normalizeExtraTexPackages {
  extraTexPackages = ["mathrsfs" "xcolor"]; # List of strings
  discoveredPackages = {}; # Not used for list input
}
# => { mathrsfs = <derivation>; xcolor = <derivation>; }

normalizeExtraTexPackages {
  extraTexPackages = [pkgs.texlive.mathrsfs pkgs.texlive.xcolor]; # List of derivations
  discoveredPackages = {}; # Not used for list input
}
# => { mathrsfs = <derivation>; xcolor = <derivation>; }

normalizeExtraTexPackages {
  extraTexPackages = discovered:
    if builtins.hasAttr "tikz" discovered
    then [pkgs.texlive.pgfplots pkgs.texlive.circuitikz]
    else [];
  discoveredPackages = { tikz = pkgs.texlive.pgf; }; # Example discovered packages
}
# => { pgfplots = <derivation>; circuitikz = <derivation>; } (if tikz is discovered)
```

For more detailed examples, refer to the test cases:

- See `tests/extraTexPackages.nix` for usage examples within `mkLatexPdfDocument`.
- See `tests/normalizeExtraTexPackages.nix` for comprehensive examples.

______________________________________________________________________
