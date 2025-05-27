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
