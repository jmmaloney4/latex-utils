# ✨ latex-utils: Reproducible LaTeX Document Packaging with Nix Flakes

**latex-utils** is a Nix flake module for building LaTeX documents as reproducible Nix packages.

---

## Table of Contents
- [Features](#features)
- [Quickstart](#quickstart)
- [Automatic Package Discovery](#automatic-package-discovery)
- [Module-Level Extra Packages](#module-level-extra-packages)
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
- **Module-level packages**: Define common packages once for all documents.
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
   # In your flake.nix
   # ...
   outputs = { self, flake-parts, latex-utils, nixpkgs }@inputs:
     flake-parts.lib.mkFlake { inherit self inputs; } {
       systems = [ "x86_4-linux" /* ... other systems ... */ ];
       imports = [
         inputs.latex-utils.flakeModule # Use flakeModule for flake-parts
       ];
       perSystem = { config, pkgs, system, ... }: {
         # Configure latex-utils options
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
         # Optionally, re-export the dev shell for convenience
         devShells.default = config.latex-utils.devShells.default;
       };
     };
   # ...
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

### Note on `mathrsfs` Package

The `mathrsfs.sty` style, used for script letters in math, requires special handling in minimal TeX Live setups. It is part of Jörg Knappen's `jknapltx` bundle, and the glyphs themselves come from the `rsfs` font package.

If you are using a minimal TeX Live scheme (like `scheme-small`) and need `\usepackage{mathrsfs}`, you must ensure both TeX Live packages `jknapltx` and `rsfs` are included in your environment.

**How to ensure mathrsfs works:**

#### Option 1: Use a `% CTAN:` comment in your LaTeX source

Add this line where you load `mathrsfs`:

```latex
\usepackage{mathrsfs} % CTAN: jknapltx, rsfs
```

This tells `latex-utils` to include both the `jknapltx` (provides `mathrsfs.sty`) and `rsfs` (provides the fonts) TeX Live packages, even if the package name doesn't match exactly.

#### Option 2: Use `extraTexPackages` in your Nix configuration

If you want to guarantee these packages are included regardless of auto-detection, add them to your Nix configuration:

**At the module level (for all documents):**
```nix
latex-utils.extraTexPackages = [ "jknapltx" "rsfs" ];
```

**Or at the document level:**
```nix
latex-utils.documents = [
  {
    name = "mydoc.pdf";
    src = ./.;
    extraTexPackages = [ "jknapltx" "rsfs" ];
  }
];
```

**Summary Table:**

| Approach                | What to add                                  |
|-------------------------|----------------------------------------------|
| In LaTeX source         | `\usepackage{mathrsfs} % CTAN: jknapltx, rsfs` |
| In Nix configuration    | `extraTexPackages = [ "jknapltx" "rsfs" ];`   |

**How `latex-utils` handles this:**

- **Automatic Discovery**: While `latex-utils` strives to detect packages like `mathrsfs` automatically, the most reliable way to ensure both `jknapltx` (which provides `mathrsfs.sty`) and `rsfs` (which provides the fonts) are included is by manual specification, especially in very minimal setups.
- **Manual Addition**: It's safer to explicitly add them if you encounter issues:
  - You can add them to `latex-utils.extraTexPackages` at the module level if needed by many documents:
    ```nix
    latex-utils.extraTexPackages = [ "jknapltx" "rsfs" /* ... other common packages ... */ ];
    ```
  - Or at the document level:
    ```nix
    latex-utils.documents = [
      {
        name = "mydoc.pdf";
        src = ./.;
        extraTexPackages = [ "jknapltx" "rsfs" ];
      }
    ];
    ```
- **Nix Context**: For reference, if you were managing your TeX environment directly with Nix, you would use:
  ```nix
  # Example with texlive.combine
  mytex = pkgs.texlive.combine {
    inherit (pkgs.texlive) scheme-small; # or your preferred minimal scheme
    jknapltx; # Provides mathrsfs.sty
    rsfs;     # Provides the fonts
  };

  # Example with texlive.withPackages
  mytex = pkgs.texlive.withPackages (ps: [ ps.jknapltx ps.rsfs ]);
  ```

**Key takeaway**: Larger TeX Live schemes (e.g., `scheme-medium`, `scheme-full`) typically include `jknapltx` and `rsfs` by default. This note is most relevant when using minimal schemes to keep your Nix closure size small. If `\usepackage{mathrsfs}` fails, ensure both `jknapltx` and `rsfs` are present in your `extraTexPackages`.

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

## Module-Level Extra Packages

You can now specify common TeX Live packages at the module level that will be included for ALL documents, the unified TeX environment, and dev shells.

### Basic Usage

```nix
{
  # Define packages once for all documents
  latex-utils.extraTexPackages = [
    "amsmath"
    "amssymb"
    "mathtools"
    "geometry"
    "fancyhdr"
  ];
  
  latex-utils.documents = [
    {
      name = "paper1.pdf";
      src = ./paper1;
      # This document gets module-level packages PLUS tikz
      extraTexPackages = ["tikz"];
    }
    {
      name = "paper2.pdf";
      src = ./paper2;
      # This document only uses module-level packages
    }
  ];
}
```
### Advanced Usage with Functions

Module-level `extraTexPackages` supports the same flexible formats as document-level:

```nix
{
  # Using derivations
  latex-utils.extraTexPackages = [
    pkgs.texlive.amsmath
    pkgs.texlive.unicode-math
    myCustomTexPackage
  ];
  
  # Or using a function (discovered will be empty at module level)
  latex-utils.extraTexPackages = discovered: [
    "amsmath"
    "amssymb"
  ] ++ lib.optionals (pkgs.stdenv.isDarwin) [
    "darwin-specific-package"
  ];
}
```

### Benefits

1. **DRY (Don't Repeat Yourself)**: Common packages are specified once instead of in each document
2. **Consistency**: Ensures all documents have access to your standard package set
3. **Flexibility**: Documents can still add their own specific packages
4. **Works without documents**: Create a TeX environment with just module-level packages

### Common Use Cases

**Research Group Template**
```nix
latex-utils.extraTexPackages = [
  # Your group's standard packages
  "amsmath" "amssymb" "mathtools"
  "natbib" "your-university-style"
];
```

**Course Materials**
```nix
latex-utils.extraTexPackages = [
  # Common to all course documents
  "beamer" "tikz" "listings"
  "xcolor" "hyperref"
];
```

**Book/Thesis Project**
```nix
latex-utils.extraTexPackages = [
  # Core typesetting stack
  "memoir" "microtype" "fontspec"
  "unicode-math" "biblatex"
];
```

### Precedence Rules

When both module-level and document-level `extraTexPackages` are specified:
- Both sets of packages are included
- Document-level packages take precedence if there's a conflict
- The unified environment includes all packages from all sources

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

When you define multiple LaTeX documents with different package requirements, latex-utils automatically creates a **unified TeX Live environment** containing all packages needed by all your documents. This environment is exposed as additional packages and three dev shell fragments:

- `config.latex-utils.build.unifiedTexShell`: composable shell fragment with unified TeX Live + helpers (no VS Code integration)
- `config.latex-utils.build.vscodeSettingsShell`: composable shell fragment that links VS Code settings.json (for use in custom shells)
- `devShells.full`: a turn-key shell with VS Code integration (enabled by default)

### Quick Setup

To use the turn-key VS Code shell (recommended for most users):
```nix
devShells.full = config.latex-utils.devShells.full;
```
Or, to make it your default shell:
```nix
devShells.default = config.latex-utils.devShells.full;
```

#### Disabling VS Code Integration

By default, VS Code integration is enabled. To disable it (e.g., for CI or headless use):
```nix
latex-utils.enableVSCode = false;
```

#### Using the Composable Fragments

If you want to compose your own shell, you can use either or both fragments:
```nix
devShells.myCustomShell = pkgs.mkShell {
  inputsFrom = [
    config.latex-utils.build.unifiedTexShell
    config.latex-utils.build.vscodeSettingsShell # Optional: links VS Code settings
  ];
  buildInputs = [ pkgs.pandoc ];
};
```
- Use only `unifiedTexShell` for a pure TeX environment (no VS Code integration).
- Add `vscodeSettingsShell` to also link `.vscode/settings.json` in your custom shell.

See [docs/advanced/devshells.md](docs/advanced/devshells.md) for more patterns and details.

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
  # Assuming you have nixpkgs input:
  # inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = inputs@{ self, flake-parts, latex-utils, nixpkgs }:
    flake-parts.lib.mkFlake { inherit self inputs; } {
      systems = [ "x86_4-linux" ]; # Add other systems as needed
      imports = [ inputs.latex-utils.flakeModule ];

      # Module-level configurations are typically placed in perSystem
      # for flake-parts modules, or can be at this top level if
      # the module is designed to pick them up (latex-utils does).
      perSystem = { config, pkgs, system, ... }: {
        latex-utils.extraTexPackages = [
          "amsmath"
          "geometry"
          "hyperref"
        ];

        latex-utils.documents = [
          {
            name = "thesis.pdf";
            src = ./.;
            # Uses module packages + any discovered packages
          }
          {
            name = "poster.pdf";
            src = ./poster;
            inputFile = "poster.tex";
            # Add poster-specific packages
            extraTexPackages = ["tikzposter" "tikz"];
          }
        ];

        # Use the unified VSCode dev shell provided by latex-utils
        devShells.full = config.latex-utils.devShells.full;
        # Or if you prefer a named shell:
        # devShells.latex = config.latex-utils.devShells.default;
      };
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
