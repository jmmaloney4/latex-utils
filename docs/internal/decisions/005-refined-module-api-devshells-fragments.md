# ADR 005: Refined `latex-utils` Module API for DevShells and Fragments

**Status:** Implemented\
**Date:** 2024-05-16\
**Implementation Date:** 2025-06-04\
**Author:** AI Agent & User

______________________________________________________________________

### Context and Problem Statement

The current `latex-utils` module provides a `devShells.full` and several outputs under `build.*` (like `unifiedTexShell`, `vscodeSettingsShell`) that are intended as composable devshell fragments. This can be confusing, as `build` typically implies build artifacts rather than shell fragments. Additionally, the naming (`full`) could be more descriptive.

We need a clearer, more idiomatic API that distinguishes between:

1. **Composable devshell fragments:** These are minimal shells providing specific functionality (e.g., just the TeX Live environment, or just VSCode settings linkage) intended to be included in other devshells via `inputsFrom`.
2. **Complete devshells:** These are ready-to-use environments, potentially composed from the fragments.

This ADR proposes a refined API to improve clarity and usability.

### Decision Drivers

- **Clarity:** The API should clearly distinguish between fragments and complete shells.
- **Composability:** Fragments should be easily usable with `inputsFrom`.
- **Idiomatic Nix:** Align with common Nix patterns for devshells and modules.
- **User Experience:** Provide a straightforward way for users to get a basic TeX environment, a VSCode-integrated environment, or to compose their own.

### Considered Options

1. **Keep current structure:** (e.g., `build.unifiedTexShell`, `devShells.full`)

   - **Rejected:** As discussed, `build` for shell fragments is non-standard and potentially confusing. `full` is not very descriptive.

2. **Proposed New API:** (Detailed below)

   - **Accepted:** Offers better clarity, naming, and aligns well with how flake-parts modules are typically structured and used.

### Decision Outcome: New API

The `latex-utils` module will define options that, once configured (often with defaults provided by the module itself), result in the following derivations being available via the `config` argument within any `perSystem` function that imports this module. These will then be mapped by flake-parts to the flake's final `outputs` under the appropriate system paths.

1. **`config.latex-utils.unifiedTexShell`** (referenced as such within `perSystem`):

   - **Final Flake Output Path:** `outputs.latex-utils.${system}.unifiedTexShell`
   - **Type:** Derivation (composable devshell fragment).
   - **Description:** A minimal devshell fragment that provides the unified TeX Live environment (all necessary TeX packages, `latexmk`, `ltex-ls` wrapped). It does *not* include VSCode-specific integration.
   - **Intended Use (within `perSystem`):** `inputsFrom = [ config.latex-utils.unifiedTexShell ];`
   - **Intended Use (externally/tests):** Access via `outputs.latex-utils.${system}.unifiedTexShell`.

2. **`config.latex-utils.vscodeShell`** (referenced as such within `perSystem`):

   - **Final Flake Output Path:** `outputs.latex-utils.${system}.vscodeShell`
   - **Type:** Derivation (composable devshell fragment).
   - **Description:** A devshell fragment that includes everything from `config.latex-utils.unifiedTexShell` (e.g., via `inputsFrom`) and additionally handles the generation and linking of `.vscode/settings.json`.
   - **Intended Use (within `perSystem`):** `inputsFrom = [ config.latex-utils.vscodeShell ];`
   - **Intended Use (externally/tests):** Access via `outputs.latex-utils.${system}.vscodeShell`.

3. **`config.devShells.latex-utils`** (referenced as such within `perSystem` when defining it):

   - **Final Flake Output Path:** `outputs.devShells.${system}.latex-utils`
   - **Type:** Derivation (complete devshell).
   - **Description:** A complete, ready-to-use devshell, composed using `config.latex-utils.vscodeShell` via `inputsFrom`.
   - **Intended Use (within `perSystem`):** Define as `devShells.latex-utils = pkgs.mkShell { inputsFrom = [ config.latex-utils.vscodeShell ]; };`
   - **Intended Use (externally/activation):** `nix develop .#latex-utils` (maps to `outputs.devShells.${system}.latex-utils`).

**Rationale for namespacing fragments under `config.latex-utils.*`:**

- This clearly groups module-specific configuration and helper derivations.
- It avoids polluting the top-level `config.build` or other standard flake-parts outputs with shell fragments.
- `config.devShells.latex-utils` remains the standard way to access the primary, complete devShell provided by the module.

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
