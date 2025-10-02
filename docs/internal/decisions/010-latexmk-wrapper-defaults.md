# ADR 010: Replace Generated `.latexmkrc` With Shell Wrapper Defaults
*Date:* 2025-10-01
*Status:* accepted

## Context
PR #22 introduced an auto-generated `.latexmkrc` that synchronizes the selected LaTeX engine, SyncTeX, and output directory across CLI, dev shells, and VS Code. The implementation currently symlinks that file into every project on shell entry, which will overwrite any user-managed `.latexmkrc`. We need a safer way to provide consistent defaults without touching a repository's files.

## Decision
We will remove the managed `.latexmkrc` feature and instead encode the defaults in the tooling we control:
- Teach the `latexmk` wrapper shipped in the unified TeX shell to prepend the required flags (`-pdf`, engine selection, `-interaction=nonstopmode`, `-file-line-error`, `-synctex=1`, `-recorder`, `-silent`, `-bibtex`, `-output-directory=.latex-build`).
- Export those defaults through `LATEXMK_OPTS` from the shell hook so `direnv` and other shell users inherit them, while still allowing overrides via CLI flags or by modifying the environment variable.
- Point the VS Code LaTeX Workshop recipe at the wrapper instead of the raw binary so editors pick up the same behavior without duplicating options.
- Drop the `latex-utils.latexmk.emitRc` option and delete `packages.latexmkrc` along with associated documentation and tests.

## Alternatives Considered
1. **Keep the generated `.latexmkrc` and only link it when no file exists** – still risks clobbering custom setups when users rename or remove their file, and adds conditional shell logic.
2. **Keep the feature but default `emitRc = false`** – avoids data loss but makes the knob hard to discover and still writes into the work tree when enabled.
3. **Wrapper-driven defaults (chosen)** – centralizes behavior in tooling we own, avoids touching user files, and keeps VS Code/dev shell in sync.

## Consequences
- **Pros:**
  - Eliminates destructive writes in the dev shell.
  - Maintains one source of truth for latexmk defaults that VS Code and CLI share.
  - Simplifies documentation by removing `.latexmkrc` special cases.
- **Cons:**
  - Users who rely on `.latexmkrc` outside our shell must manually create one if they need project-specific tweaks.
  - Wrapper defaults must be kept in sync with documentation and tests; divergence is now harder to spot.

## Technical Details
- Update `modules/latex-utils/tex-environment.nix` to remove `.latexmkrc` generation, adjust the wrapper script, and set `LATEXMK_OPTS` in the shell hook.
- Update `modules/latex-utils/vscode-integration.nix` to reference the wrapper and remove duplicated flags if appropriate.
- Delete the `emitRc` option, the `packages.latexmkrc` export, and corresponding references in outputs, tests, README, and architecture docs.
- Add/modify tests to assert that the wrapper and exported defaults include the configured engine and shared flags.

## Supersedes / Dependencies (optional)
- depends on: `docs/internal/decisions/005-refined-module-api-devshells-fragments.md`
- depends on: `docs/internal/decisions/008-modularize-latex-utils-module.md`

## Appendices
None.
