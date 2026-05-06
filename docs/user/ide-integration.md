# IDE Integration with Unified TeX Live Environment

## Overview

The latex-utils flake-parts module creates a **unified TeX Live environment** that contains all packages needed by all LaTeX documents defined in your flake. This solves the problem of having separate TeX environments for each document and provides a single installation for IDE integration.

## Automatic VSCode Integration

For **Visual Studio Code** users, latex-utils automatically provides pre-configured settings and development environments:

### Available VSCode Components

- **`config.latex-utils.unifiedTexShell`**: Composable shell fragment with unified TeX Live environment
- **`config.latex-utils.vscodeShell`**: Composable shell fragment with TeX environment + VSCode integration
- **`config.devShells.latex-utils`**: Complete development shell with VSCode integration

### Quick VSCode Setup

**Option 1: Use the complete VS Code shell (Recommended)**

```nix
perSystem = { config, ... }: {
  devShells.default = config.devShells.latex-utils;
};
```

**Option 2: Compose your own shell with the fragments**

```nix
perSystem = { config, pkgs, ... }: {
  devShells.default = pkgs.mkShell {
    inputsFrom = [
      config.latex-utils.unifiedTexShell
      config.latex-utils.vscodeShell # Optional: adds VS Code integration
    ];
    buildInputs = [ pkgs.pandoc ];
  };
};
```

- Use only `unifiedTexShell` for a pure TeX environment (no VS Code integration).
- Add `vscodeShell` to also get VS Code integration in your custom shell.

### Enabling/Disabling VS Code Integration

By default, VS Code integration is enabled. To disable it (e.g., for CI):

```nix
latex-utils.enableVSCode = false;
```

When disabled, `config.devShells.latex-utils` will not include VS Code settings or shell hooks.

### Summary

- Use `config.devShells.latex-utils` for out-of-the-box VS Code integration.
- Use `config.latex-utils.unifiedTexShell` and `config.latex-utils.vscodeShell` for composable, editor-agnostic shells.
- Control VS Code integration with `enableVSCode`.

## Manual IDE Integration Setup

For other IDEs or custom setups, include the unified packages in your development shell:

```nix
perSystem = { self', pkgs, ... }: {
  devShells.default = pkgs.mkShell {
    buildInputs = [
      # Include the unified TeX Live environment for your IDE
      self'.packages.texlive
      self'.packages.latexmk
      self'.packages.latexindent
    ];
  };
};
```

## How It Works

### Package Collection Logic

- Scans all documents for `\usepackage` commands using `findLatexPackages`
- Collects all `extraTexPackages` from all documents
  - Accepts lists of package name strings (e.g., `["foo", "bar"]`)
  - Accepts lists of derivations (e.g., `[pkgs.texlive.foo, pkgs.texlive.bar]`)
  - Accepts functions returning lists of derivations (e.g., `discovered: [pkgs.texlive.foo]`).
  - **Note**: Lists must be homogeneous (all strings or all derivations).
- Combines discovered and extra packages into a single `texlive.combined` derivation.

### Unified Environment Creation

The module creates a single TeX Live environment containing all packages from all documents and exposes it as:

- **`texlive`**: Complete TeX Live installation with all packages
- **`latexmk`**: Wrapper script for latexmk using the unified environment

## Complete Example

```nix
{
  inputs.latex-utils.url = "github:jmmaloney4/latex-utils";
  # If latex-utils is an input of your flake-parts flake:
  # imports = [ inputs.latex-utils.flakeModules.latex-utils ];
  # Or, if you are manually importing the module:
  imports = [ inputs.latex-utils.modules.flake.latex-utils ];

  outputs = inputs: flake-parts.lib.mkFlake { inherit inputs; } {
    imports = [ inputs.latex-utils.modules.flake.latex-utils ];
    
    latex-utils.documents = [
      {
        name = "document1.pdf";
        src = ./doc1;
        extraTexPackages = [ "rsfs" "jknapltx" "xcolor" ]; # List of strings
      }
      {
        name = "document2.pdf";
        src = ./doc2;
        # List of derivations
        extraTexPackages = [ pkgs.texlive.pgf pkgs.texlive.amsmath ]; 
      }
      {
        name = "document3.pdf";
        src = ./doc3;
        # Function returning list of derivations
        extraTexPackages = discovered: 
          if builtins.hasAttr "biblatex" discovered 
          then [ pkgs.texlive.biblatex-apa ] 
          else [];
      }
    ];
    
    perSystem = { config, self', pkgs, ... }: {
      # Option A: Use the provided latex-utils dev shell with VS Code integration
      devShells.default = config.devShells.latex-utils;
      
      # Option B: Integrate with your existing setup
      # devShells.default = pkgs.mkShell {
      #   inputsFrom = [ config.devShells.latex-utils ];
      #   buildInputs = [ /* your other tools */ ];
      # };
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
6. **Zero Configuration**: VSCode integration works out of the box

## Package Discovery

The system automatically discovers packages from:

- `\usepackage{packagename}` commands in LaTeX source files
- `extraTexPackages` lists in document configurations
- Discovered packages from `\usepackage` and `\RequirePackage`

## Common Package Mapping Issues

Some LaTeX packages require specific nixpkgs package names:

| LaTeX Package           | nixpkgs Package     | Notes                        |
| ----------------------- | ------------------- | ---------------------------- |
| `\usepackage{mathrsfs}` | `rsfs` + `jknapltx` | Need both font and interface |
| `\usepackage{tikz}`     | `pgf`               | TikZ is part of PGF package  |

The unified environment handles these mappings automatically when specified in `extraTexPackages`.
