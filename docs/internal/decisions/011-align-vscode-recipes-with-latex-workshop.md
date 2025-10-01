# ADR 011: Align VS Code LaTeX Workshop Settings with Recipes API
*Date:* 2025-10-01
*Status:* proposed

## Context
- LaTeX Workshop deprecated the `latex-workshop.latex.toolchain` key in favour of the `latex-workshop.latex.tools` / `latex-workshop.latex.recipes` pair plus `latex-workshop.latex.recipe.default`.
- Our VS Code settings generator (`modules/latex-utils/vscode-integration.nix`) still emits `latex-workshop.latex.toolchain` and never writes the recipe settings bundle we already render.
- Because the generated settings omit the modern recipe fields, VS Code falls back to its built-in defaults; the configured engine (e.g., `xelatex`) never propagates, and checks/tests around `vscodeRecipesPackage` are effectively dead code.
- Every `nix develop` run re-symlinks `.vscode/settings.json` to the outdated JSON, so users cannot easily override this without fighting the shell hook.

## Decision
- Replace the `latex-workshop.latex.toolchain` block in the default VS Code settings with:
  - `latex-workshop.latex.tools` describing the wrapper-backed tool for the selected engine.
  - `latex-workshop.latex.recipes` containing a single recipe pointing to that tool.
  - `latex-workshop.latex.recipe.default` set to the recipe name so manual and auto builds stay consistent.
- Emit these keys directly inside the main settings JSON so the symlinked file always contains the authoritative configuration; retire the unused standalone recipes derivation unless another consumer needs it.
- Keep pointing the command to our latexmk wrapper (per ADR 010) so editor builds and CLI usage stay aligned.
- Update docs/tests to match the new settings shape and highlight the recipe-based configuration.

## Alternatives Considered
1. **Keep emitting `latex-workshop.latex.toolchain`** – Rejected because the key is deprecated and hides engine selection in VS Code.
2. **Continue generating recipes in a separate file and ask users to merge them** – Rejected; the dev shell already overwrites `.vscode/settings.json`, so a split model would still leave users without the correct settings.
3. **Embed recipes via a helper command that mutates workspace settings on demand** (chosen) – Avoids extra commands; the shell hook keeps a single source of truth.

## Consequences
- **Pros:**
  - VS Code respects the selected engine and wrapper defaults.
  - Tests and docs reflect the same configuration users receive.
  - Removes reliance on a deprecated LaTeX Workshop setting.
- **Cons:**
  - Requires minor migrations for anyone depending on the old `toolchain` key (unlikely but possible).
  - We must adjust existing tests and documentation that reference the legacy structure.

## Technical Details
- Update `modules/latex-utils/vscode-integration.nix` to emit the recipe/tool keys and drop `latex-workshop.latex.toolchain`.
- Remove or repurpose the `vscodeRecipesPackage` derivation if it is no longer needed; otherwise ensure the dev shell links it.
- Extend tests (e.g., `tests/latexmkEngineAndOutputs.nix`) to assert the settings JSON includes the recipe defaults for the selected engine.
- Refresh README/Architecture docs and note the new keys and rationale.

## Supersedes / Dependencies (optional)
- depends on: `docs/internal/decisions/010-latexmk-wrapper-defaults.md`

## Appendices
_None._
