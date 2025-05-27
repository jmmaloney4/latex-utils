# ✨ latex-utils: Reproducible LaTeX Document Packaging with Nix Flakes

**latex-utils** is a Nix flake module for building LaTeX documents as reproducible Nix packages.

---

## 🚀 Features

- **Batch build** multiple LaTeX documents—just list them in your configuration.
- **Reproducible**: Get the same PDF every time, on any machine.
- **Minimal boilerplate**: No need to repeat build logic.
- **flake-parts native**: Modern, idiomatic, and future-proof.
- **Extensible**: Add more options as needed.

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

---

## Usage Details

- **Each document** in `latex-utils.documents` becomes a Nix package.
- The package name is the `name` field, minus the `.pdf` extension (e.g., `paper.pdf` → `paper`).
- `packages.default` is set to the first document in your list.
- You can specify any number of documents.

### Document Options

| Option      | Type   | Default     | Description                        |
|-------------|--------|-------------|------------------------------------|
| `name`      | string | *(required)*| Output PDF/package name            |
| `src`       | path   | *(required)*| Source directory for your LaTeX    |
| `inputFile` | string | `main.tex`  | Main .tex file to build            |

You can extend this with more options as needed (see `mkLatexPdfDocument.nix`).

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
