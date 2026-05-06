# Documentation and API Docs Investigation

Date: 2026-05-06
Agent: Arthur
Status: Complete
Scope: README, user documentation, module/library API documentation, and Nix documentation generation options.

## Summary

The repository has useful documentation, but the documentation system is doing too much by hand. The README mixes quickstart material, tutorial content, API reference, implementation details, and troubleshooting. The user docs contain good explanations, but several examples are stale or not evaluation-tested. The module options are typed well enough to generate reference documentation with existing Nix tooling, but that generated reference is not currently part of the docs site.

The strongest path forward is:

1. Shorten the README into a landing page and quickstart.
2. Fix stale and misleading examples, especially TeX Live package names such as `tikz` versus `pgf`.
3. Generate module option reference docs with `pkgs.nixosOptionsDoc`.
4. Convert public library function comments to nixdoc-compatible `/** ... */` comments before generating library API docs.
5. Add tests that parse or evaluate docs examples so examples cannot silently drift.

No documentation changes beyond this investigation were made as part of this pass.

## Reviewed material

Documentation reviewed:

- `README.md`
- `docs/index.md`
- `docs/user/consumer-flake-example.md`
- `docs/user/library.md`
- `docs/user/devshells.md`
- `docs/user/ide-integration.md`
- `docs/user/texlive-integration.md`
- `docs/user/unit-testing.md`
- `docs/user/example-module-packages.nix`
- `docs/user/comprehensive-example.nix`
- `modules/README.md`
- `docs/internal/ARCHITECTURE.md`

Implementation reviewed:

- `flake.nix`
- `modules/latex-utils.nix`
- `modules/latex-utils/options.nix`
- `modules/latex-utils/types.nix`
- `modules/latex-utils/document-processing.nix`
- `modules/latex-utils/tex-environment.nix`
- `modules/latex-utils/outputs.nix`
- `modules/latex-utils/vscode-integration.nix`
- `lib/default.nix`
- `lib/findLatexFiles.nix`
- `lib/findLatexPackages.nix`
- `lib/mkLatexPdfDocument.nix`
- `lib/mkFontconfigCache.nix`
- `lib/normalizeExtraTexPackages.nix`
- `tests/documentationValidation.nix`
- `tests/moduleOptions.nix`
- `tests/normalizeExtraTexPackages.nix`

Tooling verified:

- `pkgs.nixosOptionsDoc`
- `pkgs.nixos-render-docs`
- `pkgs.nixdoc`

## Current API surface

### Repository flake outputs

In this repository itself, before a consumer imports the flake-parts module, the relevant outputs are:

- `packages.${system}.documentation`
- `devShells.${system}.default`
- `checks.${system}.nix-unit`
- `checks.${system}.pre-commit`
- `checks.${system}.treefmt`
- `apps.${system}.watch-documentation`
- `formatter.${system}`
- `modules.flake.latex-utils`
- `flakeModule`

Important distinction: `devShells.${system}.latex-utils` and document packages are not outputs of this repository by default. They are created in a consuming flake after that flake imports `inputs.latex-utils.modules.flake.latex-utils` or `inputs.latex-utils.flakeModule`.

### Consumer module options

The flake-parts module exposes these top-level options:

- `latex-utils.documents`
- `latex-utils.extraTexPackages`
- `latex-utils.enableVSCode`
- `latex-utils.flakeCheck`
- `latex-utils.flakeFormatter`
- `latex-utils.latexmk.engine`

The document submodule exposes:

- `name`
- `src`
- `inputFile`
- `workingDirectory`
- `extraTexPackages`

The module also exposes per-system internal/config fragments:

- `config.latex-utils.unifiedTexShell`
- `config.latex-utils.vscodeShell`

### Consumer outputs created by the module

When imported into a consuming flake, the module creates:

- `packages.<document-name>` for each configured document, where the package name is derived by removing `.pdf` from `document.name`.
- `packages.default` when at least one document exists, pointing at the first document package.
- `packages.documents` when at least one document exists, aggregating all document PDFs.
- `packages.texlive`
- `packages.latexmk`
- `packages.latexindent`
- `packages.vscodeSettings`
- `devShells.latex-utils` when VS Code integration is enabled.
- `checks.latex` when `flakeCheck = true`.
- `apps.vscode-settings-custom`.

The README should distinguish these consumer outputs from this repository's own outputs.

## How the library works

The main module path is:

1. The user configures `latex-utils.documents` and optional `extraTexPackages`.
2. The module scans source trees for LaTeX files.
3. The scanner discovers TeX package names from source text.
4. Package names, package derivations, attrsets, and function results are normalized into a TeX Live package attrset.
5. The module calls `mkLatexPdfDocument` with `_preNormalizedExtraPackages` so the lower-level builder does not need to rescan sources.
6. The module emits document packages, a unified TeX Live environment, wrappers, optional checks, and optional dev shell integration.

Important source-scanning behavior:

- `findLatexFiles` recursively finds `.tex` and `.cls` files under the configured source tree.
- `findLatexPackages` scans source text lexically.
- It recognizes `\usepackage` forms.
- It does not currently recognize `\RequirePackage`.
- It skips full-line comments.
- `% CTAN:` directives are useful when attached to non-comment lines, especially `\usepackage` lines.
- It does not follow the TeX include graph semantically. It scans matching files under the source tree.
- Unknown package names can be silently omitted during discovery.

Important TeX Live behavior:

- The unified TeX Live environment includes a base set of packages plus discovered and explicit extras.
- Current base packages include `latex-bin`, `latexmk`, `latexindent`, `biblatex`, `biber`, `csquotes`, `luaotfload`, `fontspec`, `lm`, `cm`, `ec`, `tex-gyre`, and `scheme-basic`.
- The generated `latexmk` wrapper applies default arguments and uses `.latex-build` as the output directory.
- `LATEXMK_OPTS` can alter wrapper behavior.

Important public library exports:

- `findLatexFiles`
- `findLatexPackages`
- `mkLatexPdfDocument`
- `mkLatexDocument`, deprecated alias
- `trace`

Important non-exported/internal helpers:

- `normalizeExtraTexPackages`
- `mkFontconfigCache`
- `testHelpers`

Docs should not present internal helpers as stable public API unless the project intentionally exports them.

## README findings

### Finding 1: README has too many jobs

The README currently tries to be:

- landing page
- quickstart
- tutorial
- option reference
- package-discovery reference
- IDE guide
- lower-level library guide
- troubleshooting guide

This makes first use harder and raises drift risk. The README should be a short orientation and quickstart, then link to detailed docs.

Recommended README structure:

1. What this project does.
2. 60-second flake-parts quickstart.
3. Minimal document example.
4. Common commands.
5. Core mental model.
6. Links to docs and reference pages.

### Finding 2: README should be explicit that this is a flake-parts module

The docs should say early:

- This is a flake-parts module, not a NixOS module.
- Importing the module creates outputs in the consumer flake.
- `nix build .#paper` works because `name = "paper.pdf"` maps to `packages.paper`.
- `nix develop .#latex-utils` works only in a consumer flake where the module created that dev shell.

### Finding 3: The advanced `extraTexPackages` README example is invalid

The README currently shows `latex-utils.extraTexPackages` assigned twice in one attrset. It also uses `pkgs` and `lib` without showing a valid scope, and uses placeholder package names that would fail if copied.

Fix:

- Split string-list, derivation-list, and function-form examples into separate valid examples.
- Keep README examples executable or clearly mark them as fragments.
- Avoid fake TeX package names in copy-paste examples.

### Finding 4: Override wording is misleading

The README says document-level packages override module-level packages. The implementation is better described as merging package attrsets. Duplicate package names collapse to one attrset key, but this is not a user-facing override mechanism.

Better wording:

> Module-level, discovered, and document-level packages are merged into the TeX environment. Duplicate package names collapse to one package entry.

### Finding 5: Package examples use `tikz` where the TeX Live attr is `pgf`

Several docs examples use `"tikz"` as an `extraTexPackages` string. In nixpkgs, the TeX Live package attr for TikZ is `pgf`, not `tikz`.

Correct examples:

```tex
\usepackage{tikz} % CTAN: pgf
```

or:

```nix
latex-utils.extraTexPackages = [ "pgf" ];
```

This is a high-priority documentation bug because users will copy these examples.

### Finding 6: Library API docs are currently a stub

The README says library functions are available under `lib/`, but does not clearly explain the public API boundary or how to call those functions from a consumer flake.

The docs should separate:

- public exported API from `lib/default.nix`
- internal implementation helpers
- module-first workflow versus direct function workflow

## User docs findings

### `docs/index.md`

This page is too thin. It should establish the project mental model before linking out:

- flake-parts module
- document packages
- unified TeX Live environment
- generated wrappers and dev shell integration
- generated reference docs

### `docs/user/consumer-flake-example.md`

This is the best candidate for the canonical getting-started page. It should be renamed or surfaced as the primary onboarding path.

### `docs/user/comprehensive-example.nix`

This file should either be fixed and evaluation-tested or removed.

Problems identified:

- It uses `pkgs` in top-level module option values where `pkgs` is not in scope.
- It uses fake package names.
- It uses `self'.packages.texlive` in custom scripts, which is valid only in the right per-system context.
- It is too large for onboarding.

### `docs/user/example-module-packages.nix`

This file is useful, but should avoid misleading package names. In particular, replace `tikz` package strings with `pgf` where the Nix TeX Live attr is intended.

### `docs/user/library.md`

This should become a hand-written guide plus generated library reference. The hand-written guide should answer when to use direct functions instead of the module.

### `docs/user/unit-testing.md`

This is valuable, but some of it is contributor/internal material rather than user-facing material. Consider splitting:

- user-facing example validation docs
- internal flake-parts/nix-unit harness details

## Existing docs validation

`tests/documentationValidation.nix` validates some documentation examples, but it does not catch the stale `.nix` examples under `docs/user/`.

Recommended checks:

- Parse every `.nix` file under `docs/user/`.
- Evaluate example flakes or example modules where possible.
- Keep examples real, minimal, and buildable.
- Add a check that generated option docs can be built.

## Generated module docs

### Recommendation

Use `pkgs.nixosOptionsDoc` for generated module option reference documentation.

This is the standard tool for Nix module option docs. It is not limited to NixOS modules. It can consume options from a flake-parts module once the module is evaluated with `flake-parts.lib.evalFlakeModule`.

### Verified approach

A working pattern is:

```nix
let
  f = builtins.getFlake (toString ./.);
  system = builtins.currentSystem;

  pkgs = import f.inputs.nixpkgs {
    inherit system;
  };

  eval = f.inputs.flake-parts.lib.evalFlakeModule {
    inputs = f.inputs // {
      self = f;
    };
  } {
    imports = [
      ./modules/latex-utils.nix
    ];
    systems = [ system ];
  };

  optionsDoc = pkgs.nixosOptionsDoc {
    options = eval.options.latex-utils;
  };
in
  optionsDoc.optionsCommonMark
```

`pkgs.nixosOptionsDoc` provides:

- `optionsCommonMark`
- `optionsJSON`
- `optionsAsciiDoc`
- `optionsNix`

A generated CommonMark document was successfully built during the investigation. It included all primary `latex-utils.*` options and document suboptions.

### Caveat

The generated docs exposed stale option descriptions. Before publishing generated option docs, fix descriptions/examples in `modules/latex-utils/options.nix` and `modules/latex-utils/types.nix`.

Specific stale areas:

- Function-form `extraTexPackages` docs should say the function receives discovered packages, not `pkgs.texlive`.
- List-form docs should match actual mixed string/derivation support.
- Examples should avoid fake or nonexistent package names.

## Generated library docs

### Recommendation

Use `pkgs.nixdoc` for public library function reference docs, but only after converting public function comments to nixdoc-compatible comments.

Current `lib/*.nix` comments are inconsistent. Some are normal `#` comments. Some are ordinary `/* ... */` block comments. `nixdoc` expects structured doc comments, commonly `/** ... */`, attached to functions or exported attrs in a shape it can analyze.

The best public API boundary is `lib/default.nix` because it declares what the library exports.

Recommended public functions to document first:

- `findLatexFiles`
- `findLatexPackages`
- `mkLatexPdfDocument`
- `mkLatexDocument`, marked deprecated

Potential decision needed:

- Whether `normalizeExtraTexPackages` should remain internal or be exported/documented as public API.
- Whether `trace` is a real public export or an implementation utility.

### Standard Nix function docs practice

For Nix library code, use structured comments near public functions or public attr exports. A good comment includes:

- First sentence: what the function does.
- Arguments, especially attrset arguments.
- Return value.
- Examples.
- Stability/deprecation notes if needed.

The generated reference should complement, not replace, a hand-written guide.

## Standard practice for Nix API docs

For module options:

- Put accurate `description`, `type`, `default`, and `example` on every public option.
- Generate reference docs with `pkgs.nixosOptionsDoc`.
- Render CommonMark for MkDocs-style sites.
- Keep tutorial/onboarding docs separate from generated reference docs.

For library functions:

- Put structured doc comments in the source.
- Generate reference docs with `nixdoc` when the source shape supports it.
- Keep examples self-contained and evaluation-tested where possible.

For this repository:

- `nixosOptionsDoc` is immediately viable after option text cleanup.
- `nixdoc` is viable after comment/API-boundary cleanup.
- Custom documentation generation is unnecessary.

## Recommended implementation plan

### PR 1: Documentation correctness cleanup

Goal: make existing docs accurate before generating more docs from them.

Tasks:

- Shorten README into a true quickstart and landing page.
- Move detailed package discovery and API material into docs pages.
- Replace `tikz` TeX Live package strings with `pgf`.
- Fix or remove `docs/user/comprehensive-example.nix`.
- Split invalid duplicated `extraTexPackages` examples.
- Fix stale option descriptions and examples.
- Fix MkDocs link warnings in internal ADR docs.
- Add tests that parse or evaluate docs examples.

### PR 2: Generated module option reference

Goal: add authoritative generated module API docs.

Tasks:

- Add a Nix derivation that evaluates the flake-parts module and runs `pkgs.nixosOptionsDoc`.
- Generate CommonMark module option docs.
- Add the generated page to MkDocs under a Reference section.
- Add a CI check that generated option docs build.
- Link README and getting-started docs to the generated reference.

### PR 3: Generated library function reference

Goal: document the direct function API without hand-maintained drift.

Tasks:

- Decide the public library API boundary.
- Add nixdoc-compatible comments to public exports.
- Generate library reference docs with `pkgs.nixdoc`.
- Add generated page to MkDocs under Reference.
- Keep `docs/user/library.md` as the hand-written guide.

## Risks and follow-up questions

Open design questions:

- Should `normalizeExtraTexPackages` become public API?
- Should unknown TeX Live package strings fail loudly instead of silently producing omitted or null packages?
- Should standalone `% CTAN:` comments be supported, or should docs explicitly require CTAN directives attached to package lines?
- Should `\RequirePackage` be supported by the scanner?

Recommended follow-up issue candidates:

- Generate module option reference docs with `nixosOptionsDoc`.
- Convert public library comments to nixdoc format.
- Make documentation examples evaluation-tested.
- Decide unknown TeX package behavior and scanner directive semantics.
