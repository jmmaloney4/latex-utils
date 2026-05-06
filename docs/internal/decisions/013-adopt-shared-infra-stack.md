# ADR 013: Adopt Shared Nix/GitHub Actions Infrastructure Stack

*Date:* 2026-04-15
*Status:* proposed

## Context

latex-utils currently operates with a standalone CI and Nix infrastructure:

- **CI:** garnix.io (third-party Nix build service) via `garnix.yaml`
- **Formatter:** Inline `treefmt-nix` config (alejandra + latexindent) in `flake.nix`
- **Pre-commit:** Inline `git-hooks-nix` config in `flake.nix`
- **nix-unit:** Direct input with 14 test suites (no input sanitization)
- **Flake inputs:** All standalone -- nixpkgs pinned independently, no shared module library

Five other repos in the org (garden, jackpkgs, toolbox, zeus, yard) have converged on a shared infrastructure stack built around `jmmaloney4/jackpkgs` (flake-parts module library) and `jmmaloney4/sector7` (reusable GitHub Actions workflows). latex-utils is the sole outlier.

The divergence creates maintenance overhead: formatter configs, pre-commit hooks, and CI pipelines must be maintained independently rather than inheriting improvements from the shared modules.

## Decision

Migrate latex-utils to the shared infrastructure stack in two phases. Adopt jackpkgs flake-parts modules for formatting and pre-commit, and replace garnix.io with toolbox-based GitHub Actions workflows.

### Phase 1: Core Infrastructure (required)

1. **Add `jackpkgs` as a flake input** (`github:jmmaloney4/jackpkgs`) and make `nixpkgs` follow `jackpkgs/nixpkgs` for pin consistency.
2. **Import `jackpkgs.flakeModules.default`** (or select specific modules: fmt, pre-commit). This replaces:
   - Inline `treefmt-nix` config with `jackpkgs` fmt module (keeps alejandra + latexindent, gains consistent default excludes)
   - Inline `git-hooks-nix` config with `jackpkgs` pre-commit module
   - Remove `treefmt-nix` and `git-hooks-nix` as direct inputs (provided transitively through jackpkgs)
3. **Replace garnix.io with `.github/workflows/nix.yml`** calling `jmmaloney4/sector7/.github/workflows/nix.yml@<pin>`. Delete `garnix.yaml`.
4. **Add Renovate config** (`.github/renovate.json5`) inheriting from `jmmaloney4/sector7//renovate/all.json`.

### Phase 2: CI Enhancements (recommended)

5. **Add `.github/workflows/nix-flake-update.yml`** -- weekly cron creating PRs via DeterminateSystems/update-flake-lock.
6. **Add `.github/workflows/claude.yml`** and **`claude-review.yml`** -- delegates to toolbox for `@claude` mentions in issues/PRs.
7. **Add `.github/workflows/adr-management.yml`** -- delegates to toolbox for ADR numbering enforcement on PRs touching `docs/internal/decisions/`.
8. **Add `.github/workflows/project-auto-add.yaml`** -- auto-adds new issues/PRs to GitHub Project board.

### Not in scope

- **Pulumi:** No deploy targets. This is a Nix library.
- **Python/Node modules:** No Python or Node.js source in this repo.
- **Container images:** No nix2container or docker builds needed.
- **mission-control to just-flake migration:** Optional future cleanup; not blocking.
- **mkdocs-flake:** Keep as-is; unique to this repo.

## Alternatives Considered

1. **Stay on garnix.io with standalone inputs** -- Minimizes short-term churn but latex-utils remains the only repo outside the shared stack, increasing long-term maintenance burden and divergence.
2. **Adopt jackpkgs but keep garnix.io** -- Partial adoption. Loses the benefit of toolbox's nix-eval-jobs build matrix and self-hosted runner caching. Inconsistent with other repos.
3. **Adopt shared stack (chosen)** -- Aligns latex-utils with the org standard. One-time migration cost, then inherits improvements automatically.

## Consequences

- **Pros:**
  - Single source of truth for formatter/linting config via jackpkgs fmt module
  - CI runs on self-hosted runners (faster, no garnix queue)
  - Automatic flake lock updates via Renovate + nix-flake-update bot
  - ADR numbering enforcement prevents conflicts
  - AI-assisted review via claude/claude-review workflows
  - nixpkgs pin stays synchronized with the rest of the org
- **Cons:**
  - Adds `jackpkgs` as an input, increasing flake evaluation closure
  - garnix.io provided multi-arch builds (x86_64-linux, aarch64-linux, aarch64-darwin) out of the box; toolbox nix.yml must be configured to match or accept a subset
  - jackpkgs fmt module enables formatters latex-utils doesn't need (ruff, biome, rustfmt, etc.) -- harmless but adds to closure
  - Renovate's `github-actions` manager will automatically update workflow `uses:` pins (e.g., `jmmaloney4/sector7/.github/workflows/nix.yml@main` → a SHA hash) once configured

## Technical Details

### File changes (Phase 1)

```
Modified:
  flake.nix              -- add jackpkgs input, import modules, remove inline fmt/pre-commit
  flake.lock             -- regenerated

Added:
  .github/workflows/nix.yml             -- toolbox nix.yml caller
  .github/renovate.json5                 -- inheriting toolbox presets

Removed:
  garnix.yaml                            -- replaced by GitHub Actions
```

### File changes (Phase 2)

```
Added:
  .github/workflows/nix-flake-update.yml
  .github/workflows/claude.yml
  .github/workflows/claude-review.yml
  .github/workflows/adr-management.yml
  .github/workflows/project-auto-add.yaml
```

### Inputs to remove from flake.nix

- `treefmt-nix` (provided by jackpkgs)
- `git-hooks-nix` (provided by jackpkgs)

### Inputs to keep

- `nixpkgs` (following jackpkgs/nixpkgs)
- `flake-parts`
- `systems`
- `nix-unit`
- `flake-root`
- `mission-control`
- `mkdocs-flake`
- `jackpkgs` (new)

### Reference repos

| Repo     | jackpkgs modules used                                                | toolbox workflows used                                               |
| -------- | -------------------------------------------------------------------- | -------------------------------------------------------------------- |
| garden   | fmt, checks, python, nodejs, pulumi, quarto, just                    | nix, pulumi, claude, claude-review, adr-management                   |
| jackpkgs | fmt, checks, just, pre-commit, shell, pulumi, quarto, python, nodejs | nix, claude, claude-review, adr-management                           |
| toolbox  | fmt, checks, nodejs                                                  | nix (dogfood), pnpm (dogfood), claude, claude-review, adr-management |
| zeus     | fmt, checks, python, nodejs, pulumi, quarto, just                    | nix, pulumi, rust, claude, claude-review, adr-management             |
| yard     | fmt, checks, python, nodejs, pulumi, just                            | nix, pulumi, claude, claude-review, adr-management                   |

## Supersedes / Dependencies

- depends on: `jmmaloney4/jackpkgs` (flake-parts modules)
- depends on: `jmmaloney4/sector7` (reusable GitHub Actions workflows)

## Appendices

### Appendix A: Cross-repo Infrastructure Comparison

| Dimension         | garden                   | jackpkgs                 | toolbox                  | zeus                     | yard                     | latex-utils (current)        |
| ----------------- | ------------------------ | ------------------------ | ------------------------ | ------------------------ | ------------------------ | ---------------------------- |
| CI provider       | GitHub Actions + toolbox | GitHub Actions + toolbox | GitHub Actions (dogfood) | GitHub Actions + toolbox | GitHub Actions + toolbox | garnix.io                    |
| nixpkgs source    | follows jackpkgs         | pinned (nixpkgs#483584)  | follows jackpkgs         | follows jackpkgs         | follows jackpkgs         | nixos-unstable (independent) |
| Formatter module  | jackpkgs.fmt             | jackpkgs.fmt             | jackpkgs.fmt             | jackpkgs.fmt             | jackpkgs.fmt             | inline treefmt-nix           |
| Pre-commit module | jackpkgs.pre-commit      | jackpkgs.pre-commit      | jackpkgs.pre-commit      | jackpkgs.pre-commit      | jackpkgs.pre-commit      | inline git-hooks-nix         |
| nix-unit          | no                       | yes (30+ tests)          | no                       | no                       | no                       | yes (14 tests)               |
| Runner            | self-hosted              | self-hosted              | self-hosted              | runs-on SaaS             | runs-on SaaS             | garnix hosted                |
| Renovate          | no                       | yes                      | yes (presets)            | no                       | yes (toolbox presets)    | no                           |
| Flake update bot  | yes (weekly)             | no                       | no                       | no                       | no                       | no                           |
