# 004: Testing flake-parts Modules with nix-unit

**Status:** Accepted  
**Date:** 2025-06-03  
**Author:** o4-mini (AI agent)

---

## Context and Problem Statement

The `latex-utils` project uses flake-parts to provide module outputs such as `devShells.full`, `build.unifiedTexShell`, and other per-system outputs. We need a robust, idiomatic way to write regression and property-based tests for these outputs using `nix-unit`.

The core question: **How should we test flake-parts module outputs in nix-unit?**

## Decision Drivers

- flake-parts modules are not plain NixOS/home-manager modules; they require a flake-parts context for correct evaluation.
- Contributors and agents must be able to test both pure library helpers and flake-parts outputs in a maintainable, idiomatic way.
- Avoiding anti-patterns (e.g., using `lib.evalModules` on a flake-parts module, or importing the module file directly for output tests).
- Ensuring tests are robust to changes in the main project flake and are easy to maintain.
- The flake-parts outputs function requires more than just `system` (it also needs `self`, `nixpkgs`, `pkgs`, etc.), so a helper is needed to realize outputs correctly.

## Considered Options

### 1. Import the module file directly
- **Rejected:** This does not provide the correct context for flake-parts modules. Outputs like `devShells.full` are not available, and evaluation will fail or produce incomplete results.

### 2. Use `lib.evalModules` on the module
- **Rejected:** This is only for NixOS/home-manager-style modules. It will fail with errors like "The option `perSystem` does not exist" when used on a flake-parts module.

### 3. Import the main project flake and access outputs for a system
- **Rejected:** While this works, it couples tests to the main flake's structure and config, making them fragile to unrelated changes and less clear for contributors.

### 4. Use a dedicated test harness flake (tests/flake.nix) and a helper to realize outputs
- **Accepted:** This is the idiomatic and robust approach. By creating a minimal flake-parts flake in `tests/flake.nix` that imports the module and provides minimal config, and using a helper (e.g., `tests/test-flake-helpers.nix`) to realize outputs for a system, we can test outputs in isolation. This ensures tests are stable, clear, and easy to maintain, and matches best practices in the Nix ecosystem.

## Research and Evidence

- **flake-parts documentation** and examples show that modules are loaded via the flake, not directly.
- **nix-unit documentation** and examples show both pure function and flake output testing, with flake-parts outputs accessed via a flake.
- **Other projects** (including flake-parts itself) use a test harness flake and helper for output tests.
- **Project experience:** Attempting to use `lib.evalModules` or import the module directly led to errors and incomplete outputs. Using the main flake made tests fragile to unrelated changes. The outputs function requires more than just `system`, so a helper is needed to pass all required arguments.

## Decision Outcome

- **For flake-parts module outputs** (e.g., shells, packages, apps):
  - Always test by importing the dedicated test harness flake (`tests/flake.nix`) and using a helper (e.g., `tests/test-flake-helpers.nix`) to realize outputs for a system.
- **For pure library helpers** (in `lib/`):
  - Test by importing the helper directly.
- **Never use `lib.evalModules` on a flake-parts module.**
- **Never import the module file directly to test outputs that require flake-parts context.**
- **Do not use the main project flake for output tests; use the test harness flake and helper for isolation and clarity.**

## Consequences

- Test files for flake-parts outputs will import the test harness flake and use the helper to realize outputs for a system.
- Pure library tests will continue to import helpers directly.
- Documentation (`docs/unit-testing.md`) will reference this ADR, the test harness flake, and the helper for future contributors.
- This pattern ensures maintainability, correctness, and alignment with upstream best practices.

## References
- [flake-parts documentation](https://flake.parts/)
- [nix-unit documentation](https://github.com/nix-community/nix-unit)
- [latex-utils docs/unit-testing.md](../unit-testing.md)
- [tests/test-flake-helpers.nix](../tests/test-flake-helpers.nix)

--- 