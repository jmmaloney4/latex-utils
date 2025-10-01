# latex-utils: Reproducible LaTeX Document Packaging with Nix Flakes

**latex-utils** builds LaTeX documents as Nix packages.

---

## Table of Contents
- [Features](#features)
- [Quickstart](#quickstart)
- [Composable Development Environments](#composable-development-environments)
- [Automatic Package Discovery](#automatic-package-discovery)
- [Module-Level Extra Packages](#module-level-extra-packages)
- [Usage Details](#usage-details)
- [Unified TeX Live Environment for IDE Integration](#unified-tex-live-environment-for-ide-integration)
- [Font Loading and Fontconfig Caching](#font-loading-and-fontconfig-caching)
- [Library Functions](#library-functions)
- [Full flake.nix Example](#example-full-flakenix)
- [Documentation](#documentation)

---

## Features
- Build multiple LaTeX documents from one configuration.
- Reproducible output across machines.
- Scans `\usepackage{...}` commands and includes required TeX Live packages.
- `% CTAN:` comments map package names when CTAN and nixpkgs names differ.
- Shared package lists with module-level packages.
- Minimal boilerplate for flake-parts modules.
- Create a unified TeX Live environment for IDEs.
- VSCode integration via settings fragments.
- Shell fragments compose with other environments.
- Configurable default latexmk engine shared by the dev shell wrapper and VS Code recipes.

---

## Quickstart

1. **Add latex-utils to your flake**

   ```nix
   inputs.latex-utils.url = "github:jmmaloney4/latex-utils";
   inputs.flake-parts.url = "github:hercules-ci/flake-parts";
   ```

2. **Import the module and declare your documents**

   ```nix
   # In your flake.nix
   outputs = { self, flake-parts, latex-utils, nixpkgs }@inputs:
     flake-parts.lib.mkFlake { inherit self inputs; } {
       systems = [ "x86_64-linux" ];
       imports = [
         inputs.latex-utils.modules.flake.latex-utils
       ];

       latex-utils.documents = [
         {
           name = "paper.pdf";
           src = ./.;
           # inputFile = "main.tex";
           # extraTexPackages = [];
         }
         {
           name = "slides.pdf";
           src = ./slides;
           inputFile = "slides.tex";
         }
       ];

       perSystem = { config, pkgs, system, ... }: {
         # One-liner: use the ready-made dev shell
         devShells.default = config.devShells.latex-utils;
       };
     };
   ```

3. **Build your PDFs**

   ```sh
   nix build .#paper
   nix build .#slides
   nix build .#default
   ```

4. **Enter the development environment**

   ```sh
   nix develop
   nix develop .#latex-utils
   ```

   latex-utils scans your `.tex` files for packages and adds them automatically. The development shell includes LaTeX Workshop and LTeX-LS configuration.

---

## Composable Development Environments

latex-utils supplies shell fragments to create custom development environments.

### Available Shell Components

| Component               | Access Path                             | Description                                |
|-------------------------|-----------------------------------------|--------------------------------------------|
| Unified TeX Shell       | `config.latex-utils.unifiedTexShell`    | TeX Live with packages, latexmk, ltex-ls   |
| VSCode Shell            | `config.latex-utils.vscodeShell`        | Unified TeX shell plus VSCode settings     |
| Complete DevShell       | `config.devShells.latex-utils`          | Ready-to-use shell (uses VSCode shell)     |

### Usage Patterns

- Prefer a single fragment. `config.latex-utils.vscodeShell` already includes the unified TeX environment. Composing both fragments just duplicates shellHook messages.

Use the complete dev shell:

```nix
{
  latex-utils.documents = [ /* ... */ ];

  perSystem = { config, ... }: {
    devShells.default = config.devShells.latex-utils;
  };
}
```

Compose your own shell without VSCode integration:

```nix
{
  latex-utils.documents = [ /* ... */ ];
  latex-utils.enableVSCode = false;

  perSystem = { config, pkgs, ... }: {
    devShells.my-latex = pkgs.mkShell {
      inputsFrom = [ config.latex-utils.unifiedTexShell ];
      buildInputs = [ pkgs.git pkgs.my-custom-tool ];
      shellHook = ''
        echo "Custom LaTeX environment ready!"
      '';
    };
  };
}
```

Extend the VSCode shell:

```nix
{
  latex-utils.documents = [ /* ... */ ];

  perSystem = { config, pkgs, ... }: {
    devShells.extended-latex = pkgs.mkShell {
      inputsFrom = [ config.latex-utils.vscodeShell ];
      buildInputs = [
        pkgs.pandoc
        pkgs.imagemagick
        pkgs.inkscape
      ];
    };
  };
}
```

### Configuration Options

| Option                           | Type                | Default     | Description                                   |
|----------------------------------|---------------------|-------------|-----------------------------------------------|
| `latex-utils.enableVSCode`       | `bool`              | `true`      | Enable VSCode integration in dev shells       |
| `latex-utils.documents`          | `list`              | `[]`        | Documents to build                            |
| `latex-utils.extraTexPackages`   | `list` or function  | `[]`        | Additional packages for all documents         |
| `latex-utils.latexmk.engine`     | `enum`              | `"lualatex"` | Default engine: `lualatex`/`xelatex`/`pdflatex` |

Shell fragments can be accessed from flake outputs:

```sh
nix develop github:jmmaloney4/latex-utils#latex-utils.x86_64-linux.unifiedTexShell
nix develop github:jmmaloney4/latex-utils#latex-utils.x86_64-linux.vscodeShell
```

---

## Avoiding TeX Live Environment Conflicts

When shells include tools that provide their own TeX Live installations (for example, treefmt with latexindent), PATH conflicts can occur.

### Solution

Configure treefmt to use a latexindent wrapper that points to the unified environment:

```nix
{
  latex-utils.documents = [ /* ... */ ];

  perSystem = { config, pkgs, lib, self', ... }: {
    treefmt.config = {
      inherit (config.flake-root) projectRootFile;
      package = pkgs.treefmt;
      programs.alejandra.enable = true;
      programs.latexindent = {
        enable = true;
        package = self'.packages.latexindent;
      };
    };

    devShells.default = pkgs.mkShell {
      inputsFrom = [ config.latex-utils.vscodeShell ];
      buildInputs = [
        config.treefmt.build.wrapper
        # additional tools
      ];
    };
  };
}
```

Key points
- `self'.packages.texlive` contains all discovered packages.
- `lib.getExe' self'.packages.texlive "latexindent"` extracts the binary path.
- Use `config.devShells.latex-utils` or `config.latex-utils.vscodeShell` instead of composing both fragments.

---

## Automatic Package Discovery

latex-utils scans your sources to find required packages.

1. Recursively searches `.tex` and `.cls` files.
2. Reads `\usepackage{...}` commands to determine package names.
3. Adds the corresponding packages.
4. Combines them with any `extraTexPackages`.

### Supported Formats

```latex
% Single package
\usepackage{amsmath}

% Multiple packages
\usepackage{amsmath, amssymb, amsthm}

% Packages with options
\usepackage[utf8]{inputenc}
\usepackage[margin=1in]{geometry}

% Complex options
\usepackage[backend=biber, style=alphabetic]{biblatex}
```

### CTAN Package Name Mapping

```latex
\usepackage{tikz}      % CTAN: pgf
\usepackage{beamer}    % CTAN: beamer
\usepackage{algorithm} % CTAN: algorithms
\usepackage{somepackage} % CTAN: ctanpkg1, ctanpkg2
```

### Manual Package Override

```nix
latex-utils.documents = [
  {
    name = "mydoc.pdf";
    src = ./.;
    extraTexPackages = [
      "mathrsfs"
      "xcolor"
    ];
  }
];
```

### Note on `mathrsfs` Package

Minimal TeX Live schemes may omit packages required for `\usepackage{mathrsfs}`. Include both `jknapltx` and `rsfs`:

```latex
\usepackage{mathrsfs} % CTAN: jknapltx, rsfs
```

or in the Nix configuration:

```nix
latex-utils.extraTexPackages = [ "jknapltx" "rsfs" ];
```

Larger TeX Live schemes generally include them.

### Example: Complex Document Structure

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

latex-utils detects `amsmath`, `amssymb`, `pgf`, `biblatex`, `algorithms`, and `listings`.

```nix
latex-utils.documents = [
  {
    name = "paper.pdf";
    src = ./.;
  }
];
```

---

## Module-Level Extra Packages

Specify TeX Live packages once for all documents.

```nix
{
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
      extraTexPackages = [ "tikz" ];
    }
    {
      name = "paper2.pdf";
      src = ./paper2;
    }
  ];
}
```

### Advanced Usage with Functions

```nix
{
  latex-utils.extraTexPackages = [
    pkgs.texlive.amsmath
    pkgs.texlive.unicode-math
    myCustomTexPackage
  ];

  latex-utils.extraTexPackages = discovered: [
    "amsmath"
    "amssymb"
  ] ++ lib.optionals (pkgs.stdenv.isDarwin) [
    "darwin-specific-package"
  ];
}
```

Benefits
1. Avoids repeating common packages.
2. Keeps documents consistent.
3. Documents can still specify their own packages.
4. Works even without specific documents.

Common use cases include group templates, course materials, and large projects.

### Precedence Rules
- Document-level packages override module-level packages if necessary.
- The unified environment includes all packages from all levels.

---

## Usage Details

- Each entry in `latex-utils.documents` becomes a Nix package.
- The package name is `name` without `.pdf`.
- `packages.default` is the first document listed.

### Document Options

| Option             | Type                | Default      | Description                                |
|--------------------|---------------------|--------------|--------------------------------------------|
| `name`             | `string`            | required     | PDF and package name                       |
| `src`              | `path`              | required     | Source directory                           |
| `inputFile`        | `string`            | `main.tex`   | Main `.tex` file                           |
| `extraTexPackages` | `list` or function  | `[]`         | Additional packages                        |

### Enhanced extraTexPackages Support

```nix
latex-utils.documents = [
  {
    name = "mydoc.pdf";
    src = ./.;
    extraTexPackages = [ "mathrsfs" "xcolor" ];
  }
];
```

```nix
latex-utils.documents = [
  {
    name = "mydoc.pdf";
    src = ./.;
    extraTexPackages = [
      pkgs.texlive.mathrsfs
      pkgs.texlive.xcolor
      myCustomTexPackage
    ];
  }
];
```

```nix
latex-utils.documents = [
  {
    name = "mydoc.pdf";
    src = ./.;
    extraTexPackages = [
      "mathrsfs"
      pkgs.texlive.xcolor
      myCustomTexPackage
    ];
  }
];
```

```nix
latex-utils.documents = [
  {
    name = "mydoc.pdf";
    src = ./.;
    extraTexPackages = discovered:
      if builtins.hasAttr "tikz" discovered
      then [ "pgfplots" "pgfplotstable" ]
      else [ "standalone" ];
  }
];
```

```nix
latex-utils.documents = [
  {
    name = "mydoc.pdf";
    src = ./.;
    extraTexPackages = discovered: [
      "xcolor"
      pkgs.texlive.mathrsfs
    ] ++ (
      if builtins.hasAttr "amsmath" discovered
      then [ pkgs.texlive.amssymb pkgs.texlive.amsthm ]
      else []
    );
  }
];
```

Functions receive discovered packages as derivations and return a list of strings or derivations. This allows conditional package inclusion.

---

## Unified TeX Live Environment for IDE Integration

latex-utils builds a TeX Live environment that contains all required packages.

- `config.latex-utils.unifiedTexShell` provides the environment.
- `config.latex-utils.vscodeShell` adds VSCode integration.
- `config.devShells.latex-utils` is the complete shell.

### Quick Setup

```nix
devShells.default = config.devShells.latex-utils;
```

### Engine and Recipes

- Set default engine (for CLI, VS Code, and recipes):

```nix
latex-utils.latexmk.engine = "xelatex"; # or "lualatex", "pdflatex"
```

- Generated outputs:
  - `packages.latexmk` → wrapper script that injects shared defaults (engine, outDir, synctex, bibtex)
  - `packages.vscodeSettings` → VS Code settings JSON with LaTeX Workshop recipes/tools wired to the wrapper

- When you enter the dev shell we set `LATEXMK_OPTS` to the same defaults, so CLI and `direnv` workflows match VS Code out of the box.

### Disabling VS Code Integration

```nix
latex-utils.enableVSCode = false;
```

### Using the Composable Fragments

```nix
devShells.myCustomShell = pkgs.mkShell {
  inputsFrom = [
    config.latex-utils.vscodeShell
  ];
  buildInputs = [ pkgs.pandoc ];
};
```

Use only `unifiedTexShell` for a TeX environment without VS Code.

---

## Font Loading and Fontconfig Caching

latex-utils prebuilds a fontconfig cache containing all fonts from your TeX environment. This cache is reused to avoid rebuilding it for each document. Updates to the font set trigger a cache rebuild.

---

## Example: Full flake.nix

```nix
{
  description = "A sample LaTeX project using latex-utils";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    latex-utils.url = "github:jmmaloney4/latex-utils";
    git-hooks-nix.url = "github:cachix/git-hooks.nix";
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs = { self, flake-parts, latex-utils, nixpkgs, ... }@inputs:
    flake-parts.lib.mkFlake { inherit self inputs; } {
      systems = [ "x86_64-linux" ];

      imports = [
        inputs.latex-utils.modules.flake.latex-utils
        # inputs.git-hooks-nix.flakeModule
        # inputs.treefmt-nix.flakeModule
      ];

      latex-utils.extraTexPackages = [
        "amsmath"
        "geometry"
        "hyperref"
      ];

      latex-utils.latexmk.engine = "lualatex"; # default

      latex-utils.documents = [
        {
          name = "thesis.pdf";
          src = ./.;
        }
        {
          name = "poster.pdf";
          src = ./poster;
          inputFile = "poster.tex";
          extraTexPackages = [ "tikzposter" "tikz" ];
        }
      ];

      perSystem = { config, pkgs, system, lib, ... }: {
        devShells.default = config.devShells.latex-utils;
      };
    };
}
```

---

## Library Functions

Utility functions are available under `lib/`.

---

## Documentation

Documentation is in `docs/` and uses [mkdocs](https://www.mkdocs.org/).

Build the docs:

```bash
nix build .#documentation
```

Live preview:

```bash
nix run .#watch-documentation
```

---
