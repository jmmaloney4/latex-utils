# Development Guidelines

This document outlines key development practices, testing procedures, and change management for the `latex-utils` project.

## Architecture

Before making any significant code changes, especially to the Nix code in `lib/`, `modules/`, or `flake.nix`:

- ALWAYS review `docs/ARCHITECTURE.md` (if it exists).
- Consult any relevant Architectural Decision Records (ADRs) in `docs/decisions/`.
- Your plan or commit message should include a brief summary of how your changes align with the existing architecture.

## Running Unit Tests

This project uses `nix-unit` for running unit tests. The tests are defined in the `tests/` directory and configured in `flake.nix`.

To run all unit tests:

```bash
nix flake check -L
```

Or, to run tests with `nix-unit` directly (which `nix flake check` should invoke for the `nix-unit` checks):

```bash
nix run .#nix-unit
```

This will execute all test suites defined in `flake.nix` under `perSystem.config.nix-unit.tests`. Ensure all tests pass before committing changes, especially those affecting the Nix logic.

## Change Management & Logging

Effective change management is crucial for maintaining the stability and clarity of the project.

### Agent Changelog Requirements

**For every LLM-driven change:**

- **BEFORE committing**, ensure an agent changelog entry is created.
- Entries should be individual Markdown files in `docs/agent_logs/` named `<TIMESTAMP>-<agent_id>.md`.
    - Timestamps **must** be in UTC with a `Z` suffix (e.g., `2025-06-03T06:00:00Z`).
    - A helpful command to generate this format on Linux/macOS is: `date -u +%Y-%m-%dT%H:%M:%SZ`
    - `<agent_id>` should be a unique identifier for the agent making the change (e.g., `gemini-assisted-refactor`).
- Each entry should clearly describe:
    - The changes made.
    - The reasoning behind the changes.
    - How it aligns with the project architecture (if applicable).
    - Any ADRs referenced or created.

**Changelog Protection:**

- `docs/agent_logs/` files should **not** be manually modified by humans. If corrections are needed, a new entry should be made by an agent, or an issue should be raised.

### Architectural Decision Records (ADRs)

For significant architectural changes (e.g., adding/removing more than 200 lines in `lib/`, `modules/`, or `template/`, or introducing new major features/abstractions):

- An ADR **must** be created or updated in `docs/decisions/`.
- Use `docs/decisions/000-adr-template.md` as a template for new ADRs.
- ADRs should document the context, decision made, and consequences of the architectural change.

## File Organization

- **Module Hygiene**: New Nix files under `lib/`, `modules/`, or `template/` must be appropriately exported or documented (e.g., in a `README.md` or a `default.nix` within their respective component directory). Avoid orphaned modules.
- **Documentation Structure**: Ensure `docs/decisions/000-adr-template.md` and `docs/agent_logs/.gitkeep` exist.

## Nix Flake Hygiene

- After modifying `flake.nix`, you **must** run `nix flake update` or `nix flake lock --update-input <input-name>` (if only a specific input changed) to update `flake.lock`.
- Include both `flake.nix` and `flake.lock` changes in the same commit.

## LaTeX-Specific Requirements

- **Template Changes**: Modifications to templates under `template/` should have corresponding tests in `tests/`. Templates should be validated against common LaTeX distributions.
- **Library Functions**: New Nix library functions in `lib/**/*.nix` must include docstring comments (Nixdoc-style if possible) explaining parameters, return values, and usage examples.

## Validation Checklist (Before Commit)

- [ ] Architecture documentation and relevant ADRs have been read.
- [ ] Agent changelog entry created for the changes.
- [ ] Unit tests pass (`nix flake check -L`).
- [ ] No orphaned modules introduced.
- [ ] Tests exist for any template changes.
- [ ] New library functions are documented.
- [ ] `flake.lock` updated if `flake.nix` changed.
- [ ] (For large changes) ADR created/updated. 