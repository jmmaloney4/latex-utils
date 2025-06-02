# ✨ latex-utils: Reproducible LaTeX Document Packaging with Nix Flakes

**latex-utils** is a Nix flake module for building LaTeX documents as reproducible Nix packages.

---

## Table of Contents
- [Features](#features)
- [Quickstart](#quickstart)
- [Automatic Package Discovery](#automatic-package-discovery)
- [Usage Details](#usage-details)
- [Unified TeX Live Environment for IDE Integration](#unified-tex-live-environment-for-ide-integration)
- [Font Loading and Fontconfig Caching](#font-loading-and-fontconfig-caching)
- [Library Functions](#library-functions)
- [Usage Examples (Tests)](#usage-examples-tests)
- [Full flake.nix Example](#example-full-flakenix)
- [Documentation](#documentation)

---

## 🚀 Features

- **Batch build** multiple LaTeX documents—just list them in your configuration.
- **Reproducible**: Get the same PDF every time, on any machine.
- **Automatic package discovery**: Scans your LaTeX source files for `\usepackage{...}` commands and automatically includes the required TeX Live packages—no manual package management needed.
- **Smart CTAN mapping**: Use `% CTAN: packagename` comments when nixpkgs and CTAN package names differ.
- **Minimal boilerplate**: No need to repeat build logic.
- **flake-parts native**: Modern, idiomatic, and future-proof.
- **Extensible**: Add more options as needed.
- **Unified TeX Live environment**: Single TeX installation with all packages for IDE integration.
- **VSCode integration**: Automatic LaTeX Workshop and LTeX-LS configuration.

---

## Quickstart

1. **Add latex-utils to your flake**:

   ```nix
   inputs.latex-utils.url = "github:jmmaloney4/latex-utils";
   inputs.flake-parts.url = "github:hercules-ci/flake-parts";
   ```

2. **Import the module and declare your documents**:

   ```nix
   {
     imports = [ inputs.latex-utils.modules.latex-utils ];
     latex-utils.documents = [
       {
         name = "paper.pdf";
         src = ./.;
         # inputFile = "main.tex"; # optional, defaults to main.tex
         # extraTexPackages = []; # optional, for packages not auto-detected
       }
       {
         name = "slides.pdf";
         src = ./slides;
         inputFile = "slides.tex";
       }
     ];
   }
   ```

3. **Build your PDFs**

   ```sh
   nix build .#paper
   nix build .#slides
   nix build .#default  # builds the first document in your list
   ```

   **That's it!** latex-utils automatically scans your `.tex` files for `\usepackage{...}` commands and includes the required TeX Live packages. No manual package management needed.

---

## Automatic Package Discovery

latex-utils automatically identifies and includes the TeX Live packages your documents need by scanning your LaTeX source files. This eliminates the need to manually specify most package dependencies.

### How It Works

When you build a document, latex-utils:

1. **Recursively scans** your source directory for LaTeX files (`.tex` and `.cls` files by default)
2. **Parses each file** to extract package names from `\usepackage{...}` commands
3. **Automatically includes** the corresponding TeX Live packages in your build environment
4. **Combines** discovered packages with any manually specified `extraTexPackages`

### Supported Package Declaration Formats

latex-utils recognizes several `\usepackage` formats:

```latex
% Single package
\usepackage{amsmath}

% Multiple packages in one command
\usepackage{amsmath, amssymb, amsthm}

% Packages with options
\usepackage[utf8]{inputenc}
\usepackage[margin=1in]{geometry}

% Packages with complex options
\usepackage[backend=biber, style=alphabetic]{biblatex}
```

### CTAN Package Name Mapping

Sometimes the package name used in `\usepackage{...}` doesn't match the nixpkgs TeX Live package name. For these cases, use a `% CTAN:` comment to specify the correct package name:

```latex
% When the LaTeX package name differs from the nixpkgs name
\usepackage{tikz}      % CTAN: pgf
\usepackage{beamer}    % CTAN: beamer
\usepackage{algorithm} % CTAN: algorithms

% Multiple CTAN packages for one \usepackage command
\usepackage{somepackage} % CTAN: ctanpkg1, ctanpkg2
```

The `% CTAN:` comment tells latex-utils to include the `pgf`, `beamer`, `algorithms`, `ctanpkg1`, and `ctanpkg2` packages from nixpkgs instead of (or in addition to) looking for packages with the exact names used in `\usepackage`.

### Which Files Are Searched

latex-utils searches for LaTeX files in your document's source directory:

- **File types**: `.tex` and `.cls` files by default
- **Search scope**: Recursive search through all subdirectories
- **Search location**: The `workingDirectory` (defaults to the root of your `src`)

This means you can organize your LaTeX project with subdirectories, custom classes, and included files—latex-utils will find and analyze them all:

```
my-thesis/
├── main.tex              # Found and scanned
├── chapters/
│   ├── intro.tex         # Found and scanned  
│   └── conclusion.tex    # Found and scanned
├── mystyle.cls           # Found and scanned
└── figures/
    └── diagram.pdf       # Ignored (not .tex/.cls)
```

### Manual Package Override

For packages that aren't automatically detected or when you need additional packages:

```nix
latex-utils.documents = [
  {
    name = "mydoc.pdf";
    src = ./.;
    extraTexPackages = [ 
      "mathrsfs"     # Additional package not used via \usepackage
      "xcolor"       # Override if auto-detection missed it
    ];
  }
];
```

### Example: Complex Document Structure

Consider this LaTeX project structure:

```latex
% main.tex
\documentclass{article}
\usepackage{amsmath, amssymb}
\usepackage{tikz}           % CTAN: pgf
\usepackage[backend=biber]{biblatex}
\input{chapters/intro}
\begin{document}
% ...
\end{document}

% chapters/intro.tex  
\usepackage{algorithm}      % CTAN: algorithms
\usepackage{listings}
```

latex-utils will automatically detect and include: `amsmath`, `amssymb`, `pgf` (via CTAN comment), `biblatex`, `algorithms` (via CTAN comment), and `listings`.

The resulting Nix configuration is simply:

```nix
latex-utils.documents = [
  {
    name = "paper.pdf";
    src = ./.;
    # No extraTexPackages needed - everything auto-detected!
  }
];
```

---

## Usage Details

- **Each document** in `latex-utils.documents` becomes a Nix package.
- The package name is the `name` field, minus the `.pdf` extension (e.g., `paper.pdf` → `paper`).
- `packages.default` is set to the first document in your list.
- You can specify any number of documents.

### Document Options

| Option            | Type   | Default     | Description                        |
|-------------------|--------|-------------|------------------------------------|
| `name`            | string | *(required)*| Output PDF/package name            |
| `src`             | path   | *(required)*| Source directory for your LaTeX    |
| `inputFile`       | string | `main.tex`  | Main .tex file to build            |
| `extraTexPackages`| list or function | `[]`        | Extra TeX Live packages (flexible format)  |

You can extend this with more options as needed (see `mkLatexPdfDocument.nix`).

### Enhanced extraTexPackages Support

The `extraTexPackages` option now supports multiple input formats for maximum flexibility:

#### 1. List of Strings (Backward Compatible)
```nix
latex-utils.documents = [
  {
    name = "mydoc.pdf";
    src = ./.;
    extraTexPackages = [ "mathrsfs" "xcolor" ];
  }
];
```

#### 2. List of Derivations
```nix
latex-utils.documents = [
  {
    name = "mydoc.pdf";
    src = ./.;
    extraTexPackages = [ 
      pkgs.texlive.mathrsfs 
      pkgs.texlive.xcolor
      myCustomTexPackage  # Custom derivation
    ];
  }
];
```

#### 3. Mixed List of Strings and Derivations
```nix
latex-utils.documents = [
  {
    name = "mydoc.pdf";
    src = ./.;
    extraTexPackages = [ 
      "mathrsfs"              # String
      pkgs.texlive.xcolor     # Derivation
      myCustomTexPackage      # Custom derivation
    ];
  }
];
```

#### 4. Function for Dynamic Package Selection
```nix
latex-utils.documents = [
  {
    name = "mydoc.pdf";
    src = ./.;
    extraTexPackages = discovered: 
      if builtins.hasAttr "tikz" discovered 
      then ["pgfplots" "pgfplotstable"]  # Add plotting packages if TikZ is used
      else ["standalone"];               # Different packages otherwise
  }
];
```

#### 5. Function Returning Mixed Lists
```nix
latex-utils.documents = [
  {
    name = "mydoc.pdf";
    src = ./.;
    extraTexPackages = discovered: [
      "xcolor"                    # Always include xcolor
      pkgs.texlive.mathrsfs       # Always include mathrsfs derivation
    ] ++ (
      if builtins.hasAttr "amsmath" discovered 
      then [pkgs.texlive.amssymb pkgs.texlive.amsthm]  # AMS packages if amsmath found
      else []
    );
  }
];
```

The function receives an attrset of discovered packages (as derivations) and must return a list of strings or derivations. This enables powerful conditional logic based on what packages your LaTeX code actually uses.

**Use cases for functions:**
- Add complementary packages when certain packages are detected
- Include different packages based on document complexity
- Add custom derivations conditionally
- Implement package compatibility rules

## Unified TeX Live Environment for IDE Integration

When you define multiple LaTeX documents with different package requirements, latex-utils automatically creates a **unified TeX Live environment** containing all packages needed by all your documents. This environment is exposed as additional packages that you can use for IDE integration.

### Quick Setup

**For VSCode users (zero configuration):**
```nix
perSystem = { self', ... }: {
  devShells.default = self'.devShells.vscode;  # Complete VSCode + TeX Live setup
};
```

**For other IDEs or custom setups:**
```nix
perSystem = { self', pkgs, ... }: {
  devShells.default = pkgs.mkShell {
    buildInputs = [
      # Include the unified TeX Live environment for your IDE
      self'.packages.texlive-unified
      self'.packages.latexmk-unified
    ];
  };
};
```

**Available packages:**
- `texlive-unified`: Complete TeX Live installation with all packages from all documents
- `latexmk-unified`: latexmk wrapper using the unified environment
- `vscode-settings`: Pre-configured VSCode settings for LaTeX Workshop + LTeX-LS
- `vscode-devshell`: Ready-to-use development shell with VSCode integration

After entering the dev shell (`nix develop`), point your IDE's LaTeX configuration to use the executables from the environment. All packages from all your documents will be available.

**➡️ [Full IDE Integration Guide](docs/ide-integration.md)**

## Font Loading and Fontconfig Caching

LaTeX engines like LuaLaTeX and XeLaTeX require a font cache (managed by fontconfig) to find and use system fonts. In Nix builds, this can be slow and unreliable if the cache is rebuilt every time or if the build environment is sandboxed.

To ensure fast, reliable, and reproducible font discovery for LuaLaTeX and XeLaTeX, **latex-utils** prebuilds the fontconfig cache in a separate Nix derivation using all fonts available in your TeX environment. This prebuilt cache is then reused in every document build, eliminating the need to regenerate the cache each time and ensuring that all fonts available to your TeX Live environment are also available to fontconfig. This approach avoids repeated slow cache generation, works seamlessly in Nix's sandboxed builds, and guarantees that any changes to your font set will automatically trigger a cache rebuild.

**If you add more fonts to your TeX environment, the cache will be automatically rebuilt.**

**Why:**
- This avoids repeated, slow font cache generation in every build.
- It ensures all fonts available to your document are also available to fontconfig.
- It makes builds more reliable in Nix's sandboxed, immutable environment.

---

## Example: Full flake.nix

```nix
{
  description = "My LaTeX project";
  inputs.latex-utils.url = "github:jmmaloney4/latex-utils";
  inputs.flake-parts.url = "github:hercules-ci/flake-parts";

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];
      imports = [ inputs.latex-utils.modules.latex-utils ];
      latex-utils.documents = [
        {
          name = "thesis.pdf";
          src = ./.;
        }
        {
          name = "poster.pdf";
          src = ./poster;
          inputFile = "poster.tex";
        }
      ];
    };
}
```

---

## Library Functions

The following utility functions are available in the `lib/` directory. See [docs/library.md](docs/library.md) for full details and advanced usage.

| Function                | Description |
|-------------------------|-------------|
| `findLatexFiles`        | Recursively finds all LaTeX source files (.tex, .cls, etc.) in a directory tree. |
| `findLatexPackages`     | Parses LaTeX source files to extract required TeX Live package names from `\usepackage` lines. |
| `normalizeExtraTexPackages` | Normalizes different input formats for `extraTexPackages` (strings, derivations, functions) to a consistent attrset of derivations. |
| `mkLatexPdfDocument`    | Builds a LaTeX document as a Nix derivation, automatically including required and extra TeX Live packages. |
| `mkFontconfigCache`     | Prebuilds the fontconfig cache for LuaLaTeX and XeLaTeX, using all fonts available in your TeX environment. |

See [docs/library.md](docs/library.md) for arguments, return values, and advanced usage.

---

## Usage Examples (Tests)

The `tests/` directory contains real-world usage examples and regression tests for the library functions and module options. See:
- `tests/extraTexPackages.nix`: Examples of using `extraTexPackages` and building multiple documents.
- `tests/findLatexPackages.nix`: Examples of parsing LaTeX files for required packages.
- `tests/unifiedTexLive.nix`: Comprehensive tests for the unified TeX Live environment functionality.

Run all tests with:
```sh
nix flake check
```

Or run just the nix-unit tests:
```sh
nix build .#checks.$(nix eval --raw --impure --expr builtins.currentSystem).nix-unit
```

---

## Documentation

- **[Library Functions](docs/library.md)** - Detailed library function reference  
- **[TeX Live Integration](docs/texlive-integration.md)** - Comprehensive guide to TeX Live package structure and the `normalizeExtraTexPackages` function
- **[IDE Integration Guide](docs/ide-integration.md)** - Complete guide for IDE setup with unified TeX Live environments
- **[Consumer Flake Example](docs/consumer-flake-example.md)** - Before/after example showing VSCode integration simplification

---