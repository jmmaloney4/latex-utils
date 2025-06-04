# ADR 005: Refined `latex-utils` Module API for DevShells and Fragments

**Status:** Proposed
**Date:** 2024-05-16
**Author:** AI Agent & User

---

### Context and Problem Statement

The current `latex-utils` module provides a `devShells.full` and several outputs under `build.*` (like `unifiedTexShell`, `vscodeSettingsShell`) that are intended as composable devshell fragments. This can be confusing, as `build` typically implies build artifacts rather than shell fragments. Additionally, the naming (`full`) could be more descriptive.

We need a clearer, more idiomatic API that distinguishes between:
1.  **Composable devshell fragments:** These are minimal shells providing specific functionality (e.g., just the TeX Live environment, or just VSCode settings linkage) intended to be included in other devshells via `inputsFrom`.
2.  **Complete devshells:** These are ready-to-use environments, potentially composed from the fragments.

This ADR proposes a refined API to improve clarity and usability.

### Decision Drivers

*   **Clarity:** The API should clearly distinguish between fragments and complete shells.
*   **Composability:** Fragments should be easily usable with `inputsFrom`.
*   **Idiomatic Nix:** Align with common Nix patterns for devshells and modules.
*   **User Experience:** Provide a straightforward way for users to get a basic TeX environment, a VSCode-integrated environment, or to compose their own.

### Considered Options

1.  **Keep current structure:** (e.g., `build.unifiedTexShell`, `devShells.full`)
    *   **Rejected:** As discussed, `build` for shell fragments is non-standard and potentially confusing. `full` is not very descriptive.

2.  **Proposed New API:** (Detailed below)
    *   **Accepted:** Offers better clarity, naming, and aligns well with how flake-parts modules are typically structured and used.

### Decision Outcome: New API

The `latex-utils` module will define options that, once configured (often with defaults provided by the module itself), result in the following derivations being available via the `config` argument within any `perSystem` function that imports this module. These will then be mapped by flake-parts to the flake's final `outputs` under the appropriate system paths.

1.  **`config.latex-utils.unifiedTexShell`** (referenced as such within `perSystem`):
    *   **Final Flake Output Path:** `outputs.latex-utils.${system}.unifiedTexShell`
    *   **Type:** Derivation (composable devshell fragment).
    *   **Description:** A minimal devshell fragment that provides the unified TeX Live environment (all necessary TeX packages, `latexmk`, `ltex-ls` wrapped). It does *not* include VSCode-specific integration.
    *   **Intended Use (within `perSystem`):** `inputsFrom = [ config.latex-utils.unifiedTexShell ];`
    *   **Intended Use (externally/tests):** Access via `outputs.latex-utils.${system}.unifiedTexShell`.

2.  **`config.latex-utils.vscodeShell`** (referenced as such within `perSystem`):
    *   **Final Flake Output Path:** `outputs.latex-utils.${system}.vscodeShell`
    *   **Type:** Derivation (composable devshell fragment).
    *   **Description:** A devshell fragment that includes everything from `config.latex-utils.unifiedTexShell` (e.g., via `inputsFrom`) and additionally handles the generation and linking of `.vscode/settings.json`.
    *   **Intended Use (within `perSystem`):** `inputsFrom = [ config.latex-utils.vscodeShell ];`
    *   **Intended Use (externally/tests):** Access via `outputs.latex-utils.${system}.vscodeShell`.

3.  **`config.devShells.latex-utils`** (referenced as such within `perSystem` when defining it):
    *   **Final Flake Output Path:** `outputs.devShells.${system}.latex-utils`
    *   **Type:** Derivation (complete devshell).
    *   **Description:** A complete, ready-to-use devshell, composed using `config.latex-utils.vscodeShell` via `inputsFrom`.
    *   **Intended Use (within `perSystem`):** Define as `devShells.latex-utils = pkgs.mkShell { inputsFrom = [ config.latex-utils.vscodeShell ]; };`
    *   **Intended Use (externally/activation):** `nix develop .#latex-utils` (maps to `outputs.devShells.${system}.latex-utils`).

**Rationale for namespacing fragments under `config.latex-utils.*`:**
*   This clearly groups module-specific configuration and helper derivations.
*   It avoids polluting the top-level `config.build` or other standard flake-parts outputs with shell fragments.
*   `config.devShells.latex-utils` remains the standard way to access the primary, complete devShell provided by the module.

### Unit Testing Strategy (Aligning with ADR 004)

Unit tests for these outputs will adhere to the pattern established in ADR 004:

*   **Test Harness Flake (`tests/flake.nix`):** This flake will import `modules/latex-utils.nix`. Its `perSystem` configuration will be minimal, primarily enabling the `latex-utils` module itself.
*   **Test Helper (`tests/test-flake-helpers.nix`):** This helper will be used to evaluate the `outputs` of the test harness flake, providing the necessary `self`, `nixpkgs`, `flake-parts`, and `latex-utils` (from the main flake's resolved inputs) arguments.
*   **Accessing Outputs in Tests:**
    *   The complete devshell will be accessed via `outputs.devShells.${system}.latex-utils`.
    *   The composable fragments will be accessed via `outputs.latex-utils.${system}.unifiedTexShell` and `outputs.latex-utils.${system}.vscodeShell`.
*   **Test Assertions:**
    *   Verify that each output is a derivation (`lib.isDerivation`).
    *   For `unifiedTexShell`: Check for the presence of key TeX Live binaries in its `buildInputs` or environment.
    *   For `vscodeShell`:
        *   Verify it includes the environment from `unifiedTexShell`.
        *   Verify its `shellHook` contains commands to link/create `.vscode/settings.json`.
    *   For `devShells.latex-utils`:
        *   Verify it includes the environment from `vscodeShell` (e.g., by checking `inputsFrom` or common environment variables/packages).
        *   Verify its `shellHook` sets up the complete environment as expected.

This approach ensures that the module's outputs are tested in a context that mirrors how they would be used by a consumer of the `latex-utils` flake, while remaining isolated and robust as per ADR 004.

### Consequences

*   **Module Implementation (`modules/latex-utils.nix`):**
    *   The current `build.unifiedTexShell` option/output will be moved/renamed to `latex-utils.unifiedTexShell`.
    *   The current `build.vscodeSettingsShell` option/output will be moved/renamed to `latex-utils.vscodeShell`, and it will be updated to ensure it transitively includes `unifiedTexShell`'s environment.
    *   The current `devShells.full` will be renamed to `devShells.latex-utils` and updated to use `config.latex-utils.vscodeShell` via `inputsFrom`.
*   **Tests:**
    *   Tests for `devShells.full` will need to be updated to test `devShells.latex-utils`.
    *   Tests for the fragments will need to be updated to access them via `config.latex-utils.unifiedTexShell` and `config.latex-utils.vscodeShell`.
*   **Documentation (`docs/unit-testing.md`, `README.md`, etc.):**
    *   Examples and references will need to be updated to reflect the new API.
*   **Main Project Flake (`flake.nix`):**
    *   If the main flake's `devShells.default` (or other shells) currently uses `config.latex-utils.build.xxx` or `config.devShells.full`, it will need to be updated.
*   **User Impact:** Users will need to update their shell configurations or `nix develop` commands if they were using the old names. The new API is clearer and more idiomatic.

--- 