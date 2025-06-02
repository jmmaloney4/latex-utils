# IDE Integration with Unified TeX Live Environment

## Overview

The latex-utils flake-parts module creates a **unified TeX Live environment** that contains all packages needed by all LaTeX documents defined in your flake. This solves the problem of having separate TeX environments for each document and provides a single installation for IDE integration.

## How It Works

### Package Collection Logic

- Scans all documents for `\usepackage` commands using `findLatexPackages`
- Collects all `extraTexPackages` from all documents
- Deduplicates packages across documents
- Combines with base packages (latex-bin, latexmk, biblatex, etc.)

### Unified Environment Creation

The module creates a single TeX Live environment containing all packages from all documents and exposes it as:

- **`texlive-unified`**: Complete TeX Live installation with all packages
- **`latexmk-unified`**: Wrapper script for latexmk using the unified environment

## IDE Integration Setup

Include the unified packages in your development shell:

```nix
perSystem = { self', pkgs, ... }: {
  devShells.default = pkgs.mkShell {
    buildInputs = [
      self'.packages.texlive-unified
      self'.packages.latexmk-unified
    ];
  };
};
```

## Complete Example

```nix
{
  inputs.latex-utils.url = "github:jmmaloney4/latex-utils";
  
  outputs = inputs: flake-parts.lib.mkFlake { inherit inputs; } {
    imports = [ inputs.latex-utils.modules.latex-utils ];
    
    latex-utils.documents = [
      {
        name = "paper1.pdf";
        src = ./.;
        extraTexPackages = [ "rsfs" "jknapltx" "xcolor" ];
      }
      {
        name = "paper2.pdf"; 
        src = ./paper2;
        extraTexPackages = [ "pgf" "amsmath" ];
      }
    ];
    
    perSystem = { self', pkgs, ... }: {
      devShells.default = pkgs.mkShell {
        buildInputs = [
          self'.packages.texlive-unified    # Complete TeX Live
          self'.packages.latexmk-unified    # latexmk wrapper
        ];
      };
    };
  };
}
```

## IDE Configuration

After entering the dev shell (`nix develop`), your IDE will have access to:
- `latexmk` with all required packages
- `lualatex`, `pdflatex`, `xelatex` with all fonts and packages
- All TeX Live binaries and utilities

Point your IDE's LaTeX configuration to use the executables from the dev shell environment.

## Benefits

1. **Single TeX Installation**: IDEs only need to point to one TeX Live installation
2. **All Packages Available**: Every package used by any document is available
3. **Efficient**: Packages are deduplicated and combined into a single derivation
4. **Consistent**: All documents use the same package versions
5. **Backwards Compatible**: Existing document definitions continue to work unchanged

## Package Discovery

The system automatically discovers packages from:

- `\usepackage{packagename}` commands in LaTeX source files
- `extraTexPackages` lists in document configurations
- Comments like `% CTAN: actualpackagename` for package name mapping

## Common Package Mapping Issues

Some LaTeX packages require specific nixpkgs package names:

| LaTeX Package | nixpkgs Package | Notes |
|---------------|-----------------|-------|
| `\usepackage{mathrsfs}` | `rsfs` + `jknapltx` | Need both font and interface |
| `\usepackage{tikz}` | `pgf` | TikZ is part of PGF package |

The unified environment handles these mappings automatically when specified in `extraTexPackages`. 