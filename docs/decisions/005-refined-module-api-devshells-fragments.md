# ADR 005: Refined `latex-utils` Module API for DevShells and Fragments

**Status:** Implemented  
**Date:** 2024-05-16  
**Implementation Date:** 2025-06-04  
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

## ReadOnly Option Configuration

### Required: `readOnly = true` for Fragment Options

The exported devshell fragment options (`unifiedTexShell` and `vscodeShell`) **must** be marked with `readOnly = true` in their option definitions. This is a critical aspect of the API design that ensures proper usage patterns.

**Implementation Pattern:**
```nix
perSystem = flake-parts-lib.mkPerSystemOption {
  options.latex-utils = {
    unifiedTexShell = lib.mkOption {
      type = lib.types.package;
      description = "Composable devshell fragment with unified TeX Live environment";
      readOnly = true;  # ← Required
    };

    vscodeShell = lib.mkOption {
      type = lib.types.package;
      description = "Composable devshell fragment with TeX environment + VSCode integration";
      readOnly = true;  # ← Required
    };
  };
};
```

### What `readOnly = true` Means

In the NixOS module system (which flake-parts uses), `readOnly = true` indicates that:

1. **These options represent computed outputs** - They are derivations produced by the module based on its configuration, rather than values that users should directly assign.

2. **Users cannot override these values** - Any attempt to set these options directly will result in a module system error, preventing misuse.

3. **The module controls their values exclusively** - Only the module itself, in its `config` section, should provide values for these options.

4. **External access is intended for consumption, not configuration** - Users and tests can access these derivations via `config.latex-utils.*` (within perSystem) or `outputs.latex-utils.${system}.*` (externally) for composition via `inputsFrom`, but should not attempt to redefine them.

### Why `readOnly = true` is Essential

**Prevents Misconfiguration:**
- Users might attempt to override these with incompatible shell definitions, breaking the module's intended behavior.
- Ensures that the module's logic for package discovery, normalization, and environment building is respected.

**Follows Established Patterns:**
- This pattern is used by other flake-parts modules like `mission-control`, which marks its computed `devShell` option as `readOnly = true`.
- Aligns with the principle that computed outputs should be distinguished from configurable inputs.

**Clarifies API Intent:**
- Makes it explicit that these are **outputs** of the module, not **inputs** to be configured.
- Encourages the correct usage pattern: configure the module-level options (like `documents`, `extraTexPackages`, `enableVSCode`) and then consume the resulting shell fragments.

**Example of Correct Usage:**
```nix
# In a user's flake.nix
{
  imports = [ inputs.latex-utils.flakeModules.default ];
  
  # Configure the module
  latex-utils = {
    documents = [ { name = "paper.pdf"; src = ./.; } ];
    extraTexPackages = [ "amsmath" "graphicx" ];
  };
  
  # Consume the computed fragments
  perSystem = { config, ... }: {
    devShells.my-custom = pkgs.mkShell {
      inputsFrom = [ config.latex-utils.vscodeShell ];
      buildInputs = [ pkgs.my-additional-tool ];
    };
  };
}
```

This approach ensures that the module's complex logic for LaTeX package discovery, TeX Live environment construction, and VSCode integration remains encapsulated and reliable, while still providing flexible composition points for users.

## Complete Module Options API Specification

The `latex-utils` module provides a carefully structured API that distinguishes between **module-level configuration options** (which are global to the module and not per-system) and **per-system derivations** (which are built for each system and available as flake outputs).

### Module-Level Options (Not Per-System)

These options configure the overall behavior of the `latex-utils` module and are **not** tied to specific systems. They are defined using standard NixOS module system patterns.

#### `latex-utils.documents`
- **Type:** `listOf docType` 
- **Default:** `[]`
- **Description:** List of LaTeX documents to build as packages
- **Per-System:** ❌ No - this is a module-level configuration
- **Access Pattern:** Available globally in the module configuration
- **Example:** 
  ```nix
  latex-utils.documents = [
    {
      name = "paper.pdf";
      src = ./.;
      inputFile = "main.tex";
      extraTexPackages = ["amsmath"];
    }
  ];
  ```

#### `latex-utils.extraTexPackages`
- **Type:** `extraTexPackagesType` (same as document-level)
- **Default:** `[]`
- **Description:** Extra TeX Live packages to include for ALL documents and environments
- **Per-System:** ❌ No - applies globally to all documents across all systems
- **Access Pattern:** Available globally in the module configuration
- **Example:**
  ```nix
  latex-utils.extraTexPackages = ["amsmath" "geometry" "hyperref"];
  ```

#### `latex-utils.enableVSCode`
- **Type:** `bool`
- **Default:** `true`
- **Description:** Whether to enable VS Code integration in devShells
- **Per-System:** ❌ No - this is a module-level feature flag
- **Access Pattern:** Controls behavior across all systems

#### `latex-utils.flakeFormatter`
- **Type:** `bool`
- **Default:** `false`
- **Description:** Whether to provide a flake formatter for .tex files
- **Per-System:** ❌ No - this is a module-level feature flag

#### `latex-utils.flakeCheck`
- **Type:** `bool`
- **Default:** `false`
- **Description:** Whether to enable a flake check that rebuilds all PDFs
- **Per-System:** ❌ No - this is a module-level feature flag

### Per-System Options and Derivations

These are defined using `flake-parts-lib.mkPerSystemOption` and follow the flake-parts convention of being system-specific. They use `mkTransposedPerSystemModule` pattern internally, meaning they're accessible both within `perSystem` contexts and as final flake outputs.

#### `latex-utils.unifiedTexShell`
- **Type:** `package` (derivation)
- **Description:** Composable devshell fragment with unified TeX Live environment
- **Per-System:** ✅ Yes - built for each system
- **Access Patterns:**
  - **Within perSystem:** `config.latex-utils.unifiedTexShell`
  - **Final flake output:** `outputs.latex-utils.${system}.unifiedTexShell`
  - **Tests:** `outputs.latex-utils.x86_64-linux.unifiedTexShell`
- **Implementation:** Uses `flake-parts-lib.mkPerSystemOption` and transposition
- **Contents:** Unified TeX Live environment, ltex-ls wrapped, latexmk

#### `latex-utils.vscodeShell`
- **Type:** `package` (derivation)
- **Description:** Composable devshell fragment with TeX environment + VSCode integration
- **Per-System:** ✅ Yes - built for each system 
- **Access Patterns:**
  - **Within perSystem:** `config.latex-utils.vscodeShell`
  - **Final flake output:** `outputs.latex-utils.${system}.vscodeShell`
  - **Tests:** `outputs.latex-utils.x86_64-linux.vscodeShell`
- **Implementation:** Uses `flake-parts-lib.mkPerSystemOption` and transposition
- **Composition:** Includes `unifiedTexShell` via `inputsFrom` plus VSCode settings

#### `devShells.latex-utils`
- **Type:** `package` (derivation)  
- **Description:** Complete, ready-to-use devshell
- **Per-System:** ✅ Yes - built for each system
- **Access Patterns:**
  - **Within perSystem:** `config.devShells.latex-utils`
  - **Final flake output:** `outputs.devShells.${system}.latex-utils`
  - **User activation:** `nix develop .#latex-utils`
- **Implementation:** Uses standard flake-parts `devShells` transposition
- **Composition:** Composed from `vscodeShell` when `enableVSCode` is true

### Document-Level Options (Nested Configuration)

Each document in `latex-utils.documents` has its own sub-options:

#### `documents.*.name`
- **Type:** `str`
- **Description:** Name of the output PDF/package
- **Example:** `"my-paper.pdf"`

#### `documents.*.src`
- **Type:** `path`
- **Description:** Source directory for the LaTeX document
- **Example:** `./my-paper`

#### `documents.*.inputFile`
- **Type:** `str`
- **Default:** `"main.tex"`
- **Description:** Main .tex file (relative to src)

#### `documents.*.workingDirectory`
- **Type:** `str`
- **Default:** `"."`
- **Description:** Working directory within src for the LaTeX document

#### `documents.*.extraTexPackages`
- **Type:** `extraTexPackagesType`
- **Default:** `[]`
- **Description:** Document-specific TeX Live packages (merged with module-level packages)

### Implementation Details: How Per-System Options Work

The per-system options (`unifiedTexShell`, `vscodeShell`) are implemented using flake-parts' transposition mechanism:

1. **Option Definition:** Uses `flake-parts-lib.mkPerSystemOption` to define the option that can be configured within each system's context.

2. **Transposition Registration:** The module registers these options with the transposition system via `config.transposition.latex-utils = {};`.

3. **Automatic Output Generation:** Flake-parts automatically creates the final outputs:
   - `outputs.latex-utils.${system}.unifiedTexShell`
   - `outputs.latex-utils.${system}.vscodeShell`

4. **Config Access:** Within `perSystem` contexts, these are available as:
   - `config.latex-utils.unifiedTexShell`
   - `config.latex-utils.vscodeShell`

This pattern ensures that:
- Each system gets its own correctly-built derivations
- The options are composable within `perSystem` contexts
- The outputs are externally accessible for testing and consumption
- The API is consistent with flake-parts conventions

**Note on Standard flake-parts Outputs:** The `devShells.latex-utils` follows the standard flake-parts pattern for `devShells` and doesn't require custom transposition since `devShells` is already a standard per-system output in flake-parts.

### Defining Per-System Options Idiomatically with `mkPerSystemOption`

Further investigation into common practices within the flake-parts ecosystem, notably in projects like `numtide/treefmt-nix` and `Platonic-Systems/mission-control`, reveals a preferred idiom for defining options that are intended to be part of the `perSystem` configuration.

**Why perSystem Options Are Needed for These Features**

The features described in this ADR—composable devshell fragments (`unifiedTexShell`, `vscodeShell`) and a complete devshell (`devShells.latex-utils`)—must be defined as per-system options for several reasons:

- **System-Specific Derivations:** Nix derivations (such as shells and shell fragments) are system-dependent. The available packages, binaries, and environment setup can differ between systems (e.g., `x86_64-linux` vs. `aarch64-darwin`). Defining these as perSystem options ensures each system receives the correct, compatible derivation.
- **Flake-parts Output Mapping:** Flake-parts collects perSystem options and maps them to the final flake outputs under the appropriate system key (e.g., `outputs.latex-utils.x86_64-linux.unifiedTexShell`). This enables users and tests to access the correct shell for their platform.
- **Composability and Idiomatic Usage:** By defining shell fragments and devshells as perSystem options, they can be easily composed using `inputsFrom` within the same system context, and users can reliably reference them in their own `perSystem` blocks.
- **Isolation and Reproducibility:** Per-system scoping prevents accidental cross-system contamination and ensures that each system's environment is built and tested in isolation, which is critical for reproducible development environments.

In summary, perSystem options are the idiomatic and technically necessary way to provide system-aware, composable, and externally accessible devshell fragments and complete shells in the flake-parts ecosystem.

### Unit Testing Strategy (Aligning with ADR 004)

Unit tests for these outputs will adhere to the pattern established in ADR 004:

*   **Test Harness Flake (`tests/flake.nix`):** This flake will import `modules/latex-utils.nix`. Its `perSystem` configuration will ensure `modules/latex-utils.nix` is imported, and will provide any minimal necessary values to the `latex-utils` module options to ensure `config.latex-utils.unifiedTexShell`, `config.latex-utils.vscodeShell`, and `config.devShells.latex-utils` are populated (these will typically be populated by the module's own defaults when it's imported).
*   **Test Helper (`tests/test-flake-helpers.nix`):** This helper will be used to evaluate the `outputs` of the test harness flake, providing the necessary `self`, `nixpkgs`, `flake-parts`, and `latex-utils` (from the main flake's resolved inputs) arguments.
*   **Accessing Outputs in Tests:**
    *   Unit tests operate on the final, resolved outputs of the test harness flake. In these outputs, flake-parts organizes module-provided attributes by system, hence the access pattern shown below.
    *   The complete devshell will be accessed via `outputs.devShells.${system}.latex-utils`.
    *   The composable fragments will be accessed via `outputs.latex-utils.${system}.unifiedTexShell` and `outputs.latex-utils.${system}.vscodeShell`.
    *   These paths reflect how flake-parts maps module options (e.g., `options.perSystem.latex-utils.unifiedTexShell`) to the final flake outputs.
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

*   **Module Implementation (`modules/latex-utils.nix`)**
    *   The current `build.unifiedTexShell` option/output will be moved/renamed to `latex-utils.unifiedTexShell`.
    *   The current `build.vscodeSettingsShell` option/output will be moved/renamed to `latex-utils.vscodeShell`, and it will be updated to ensure it transitively includes `unifiedTexShell`'s environment.
    *   The current `devShells.full` will be renamed to `devShells.latex-utils` and updated to use `config.latex-utils.vscodeShell` via `inputsFrom`.
*   **Tests:**
    *   Tests for `devShells.full` will need to be updated to test `devShells.latex-utils`.
    *   Tests for the fragments will need to be updated to access them via `outputs.latex-utils.${system}.unifiedTexShell` and `outputs.latex-utils.${system}.vscodeShell` (correcting the ADR's previous typo of `config.*` for test access).
*   **Documentation (`docs/unit-testing.md`, `README.md`, etc.):**
    *   Examples and references will need to be updated to reflect the new API.
*   **Main Project Flake (`flake.nix`):**
    *   If the main flake's `devShells.default` (or other shells) currently uses `config.latex-utils.build.xxx` or `config.devShells.full`, it will need to be updated.
*   **User Impact:** Users will need to update their shell configurations or `nix develop` commands if they were using the old names. The new API is clearer and more idiomatic.

---

## Appendix A: Implementation Plan

This appendix outlines the phased approach to implement the API changes described in this ADR.

**Goal:** Transition from the old `build.*` fragments and `devShells.full` to the new API (`config.latex-utils.*` for fragments and `config.devShells.latex-utils` for the complete shell).

**Phase 1: Core Module Refactoring (`modules/latex-utils.nix`)**

*   **Step 1.1: Refactor `unifiedTexShell` Fragment**
    *   **Options:** In `options.perSystem`, rename `build.unifiedTexShell` to `latex-utils.unifiedTexShell`.
    *   **Config:** In `config.perSystem`, update the definition of this fragment. Ensure any internal references to it are updated.
*   **Step 1.2: Refactor `vscodeShell` Fragment**
    *   **Options:** In `options.perSystem`, rename `build.vscodeSettingsShell` to `latex-utils.vscodeShell`.
    *   **Config:** In `config.perSystem`, update its definition.
    *   **Composition:** Ensure `config.latex-utils.vscodeShell` correctly includes the environment from `config.latex-utils.unifiedTexShell`.
*   **Step 1.3: Refactor `devShells.full` to `devShells.latex-utils`**
    *   **Options:** In `options.perSystem.devShells`, rename the option `full` to `latex-utils`.
    *   **Config:** In `config.perSystem.devShells`, update the definition of the now-named `latex-utils` shell.
    *   **Composition:** Ensure this shell is composed using `config.latex-utils.vscodeShell` via `inputsFrom`.
*   **Step 1.4: Clean Up Old `build.*` Shell Fragment Options**
    *   Remove the old `options.perSystem.build.unifiedTexShell` and `options.perSystem.build.vscodeSettingsShell` from the module options if they were distinct definitions.

**Phase 2: Update Main Project Flake (`flake.nix`)**

*   **Step 2.1: Update `devShells.default` and any other custom devshells.**
    *   Search for any usage of `config.latex-utils.build.unifiedTexShell`, `config.latex-utils.build.vscodeSettingsShell`, or `config.devShells.full`.
    *   Replace them with the new paths as defined in ADR 005:
        *   `config.latex-utils.unifiedTexShell`
        *   `config.latex-utils.vscodeShell`
        *   For the complete shell, if you were referencing it directly, it would be `config.devShells.latex-utils`.

**Phase 3: Update Unit Tests**

*   **Step 3.1: Update Tests for the Complete DevShell**
    *   The test file `tests/devShellsFull.nix` should be renamed (e.g., to `tests/devShellLatexUtils.nix` or similar if it exclusively tests this shell).
    *   Update the test to target `outputs.devShells.${system}.latex-utils`.
*   **Step 3.2: Update Tests for DevShell Fragments**
    *   In `tests/devShellFragments.nix` (or its new equivalent if you restructure tests):
        *   Change access from `outputs.build.${system}.unifiedTexShell` to `outputs.latex-utils.${system}.unifiedTexShell`.
        *   Change access from `outputs.build.${system}.vscodeSettingsShell` to `outputs.latex-utils.${system}.vscodeShell`.
*   **Step 3.3: Verify and Adjust Test Assertions**
    *   Ensure assertions correctly reflect the new structure and composition.

**Phase 4: Update Documentation**

*   **Step 4.1: `README.md`**
    *   Update all examples of devshell usage and fragment composition.
*   **Step 4.2: `docs/unit-testing.md`**
    *   Ensure any example code snippets or references to shell outputs reflect the new API.
*   **Step 4.3: Other Documentation Files**
    *   Perform a quick review for any outdated references.

**Phase 5: Validation and Finalization**

*   **Step 5.1: Run `nix flake check -L`**.
*   **Step 5.2: Manually Test DevShell Activation** (`nix develop`, `nix develop .#latex-utils`).
*   **Step 5.3: (If applicable) Test VSCode Integration**.
*   **Step 5.4: Commit Changes** (new agent log, update `flake.lock` if `flake.nix` changed).

---

## Appendix B: Detailed Explanation of Test Structure and Output Access

This appendix clarifies why unit tests for flake-parts module outputs (as defined in ADR 004 and applied in this ADR) access these outputs using paths that include `${system}` (e.g., `outputs.latex-utils.${system}.unifiedTexShell`), rather than attempting to access them via a `config.latex-utils.unifiedTexShell`-like path directly within the test files themselves.

1.  **Role of the Test Harness Flake (`tests/flake.nix`):**
    *   As per ADR 004, `tests/flake.nix` *is* the minimal flake-parts environment. It's a self-contained flake that imports the module under test (e.g., `modules/latex-utils.nix`).
    *   Inside this test harness flake's *own* `perSystem` function, attributes configured by the imported `latex-utils` module *would* be available via `config.latex-utils.unifiedTexShell`, `config.latex-utils.vscodeShell`, etc. This is where the `latex-utils` module's logic defines these attributes based on its options.
    *   The primary purpose of this test harness flake is to produce the *final, resolved flake outputs* (e.g., `outputs.latex-utils.x86_64-linux.unifiedTexShell`) that the `latex-utils` module would generate when used by an end-user in their own flake. These outputs form the external contract of the module.

2.  **Role of Nix-Unit Test Files (e.g., `tests/devShellFragments.nix`):**
    *   These files are Nix expressions that define test cases. They are *consumers* of the final outputs generated by the test harness flake (`tests/flake.nix`).
    *   They are not themselves flake-parts modules that receive their own `config` argument directly derived from the `latex-utils` module being tested. Instead, they operate *outside* the `perSystem` evaluation context of `modules/latex-utils.nix` (and even outside the `perSystem` context of `tests/flake.nix`).
    *   Therefore, to test the module's behavior, these test files must access the *resolved outputs* of `tests/flake.nix`. By flake-parts convention, any module options that result in derivations (like our shell fragments) and are namespaced (e.g., under `options.perSystem.latex-utils.*`) will appear in the final flake outputs with the `${system}` path segment (e.g., `outputs.latex-utils.x86_64-linux.unifiedTexShell`).

3.  **Consistency with ADR 005 API Definition:**
    *   ADR 005 correctly distinguishes between:
        *   **`config.latex-utils.unifiedTexShell`**: This is how the option/attribute is referred to *within a `perSystem` context* where the `latex-utils` module has been imported and its options are available on the `config` argument (e.g., inside `modules/latex-utils.nix` itself, or in a user's main `flake.nix` when using `inputsFrom = [ config.latex-utils.unifiedTexShell ];`).
        *   **`outputs.latex-utils.${system}.unifiedTexShell`**: This is how the configured option manifests as a *final flake output*. This is the external contract that unit tests should verify.
    *   This distinction is crucial and accurately reflects how flake-parts processes module options and generates final flake outputs.

4.  **Can `${system}` be avoided in test files?**
    *   Not directly if the goal is to test the final, externalized outputs of the test harness flake, because the `${system}` path component is inherent in how flake-parts structures these outputs for per-system attributes that are not standard top-level flake outputs (like `packages`, `devShells`, `apps`, etc.).
    *   Stylistic abstraction *within* a test file is possible using a `let` binding:
        ```nix
        # In a test file like tests/devShellFragments.nix
        let
          # ... (setup for 'outputs' from the test harness flake)
          # system = pkgs.stdenv.hostPlatform.system;
          luOutputs = outputs.latex-utils.${system};
          devShellOutputs = outputs.devShells.${system};
        in {
          test_unifiedShell_exists = pkgs.nix-unit.assert {
            assertion = luOutputs.unifiedTexShell != null;
            # ...
          };
          test_completeShell_exists = pkgs.nix-unit.assert {
            assertion = devShellOutputs.latex-utils != null;
            # ...
          };
        }
        ```
        This improves readability within the test file but does not change the fact that the test is inspecting the final output structure which includes `${system}`.

5.  **Summary of Testing Flow:**
    *   The `latex-utils` module defines options (e.g., `options.perSystem.latex-utils.unifiedTexShell`).
    *   The `tests/flake.nix` (test harness) imports `modules/latex-utils.nix`. Inside the test harness's `perSystem`, the `latex-utils` module populates `config.latex-utils.unifiedTexShell` (likely with a default derivation).
    *   `flake-parts` then processes the configuration of `tests/flake.nix` and maps `config.latex-utils.unifiedTexShell` to `outputs.latex-utils.${system}.unifiedTexShell` in the final outputs of `tests/flake.nix`.
    *   The individual nix-unit test files (e.g., `tests/devShellFragments.nix`) evaluate `tests/flake.nix` (via `test-flake-helpers.nix`) and assert conditions on *its* outputs (e.g., on `outputs.latex-utils.${system}.unifiedTexShell`).

This structured approach ensures that unit tests verify the module's behavior as it would be experienced by a consumer of the flake, testing its actual output contract. The ADRs (004 and 005) are consistent with this established and robust testing methodology for flake-parts modules. 