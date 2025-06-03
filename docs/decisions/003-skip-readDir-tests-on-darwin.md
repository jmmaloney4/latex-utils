# ADR 003: Skip Nix tests using builtins.readDir on store paths on Darwin
*Date:* 2025-06-03  
*Status:* accepted

## Context

The latex-utils test suite includes tests (notably in `tests/unifiedTexLive.nix`) that use `findLatexFiles`, which relies on `builtins.readDir` to recursively scan directories. These tests create synthetic directory trees in the Nix store using `pkgs.writeTextDir` and then scan them. On Linux, this works as expected. However, on Darwin (macOS, both aarch64-darwin and x86_64-darwin), Nix does not support `builtins.readDir` on store paths that are not real directories but are instead 'diverted' or virtualized by Nix. Attempting this results in the error: `error: building using a diverted store is not supported on this platform`.

This is a known limitation of Nix on Darwin and cannot be worked around at the Nix language level.

## Decision

- All tests that use `findLatexFiles` (and thus `builtins.readDir` on store paths) are skipped on Darwin platforms.
- On Darwin, these tests are replaced with a single dummy test entry explaining the skip and the reason.
- On other platforms, the tests run as before.

## Alternatives Considered
1. **Run tests as-is on Darwin** – Rejected: Causes test failures due to Nix platform limitations.
2. **Rewrite tests to use real (non-store) paths** – Rejected: Not possible in pure Nix evaluation or the Nix build sandbox.
3. **(Chosen) Skip tests on Darwin** – Simple, clear, and avoids spurious failures on unsupported platforms.

## Consequences
- **Pros:**
  - Test suite passes on Darwin without spurious failures.
  - Clear documentation of platform limitations.
- **Cons:**
  - Reduced test coverage on Darwin for code paths involving `findLatexFiles` and recursive directory scanning.

## Supersedes / Dependencies (optional) 