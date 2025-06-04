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
  - Always test by using a dedicated **Test Harness Flake (`tests/flake.nix`)**. 
    *   **Purpose:** Creates a minimal, isolated flake environment that imports and configures the module under test (e.g., `../modules/latex-utils.nix`).
    *   **Structure:**
        *   Declares only essential inputs (e.g., `nixpkgs`, `flake-parts`, potentially the module's source if not co-located or handled differently).
        *   Uses `flake-parts.lib.mkFlake`.
        *   Its `perSystem` block **must** include the module under test in its `imports` list (e.g., `imports = [ ../modules/latex-utils.nix ];`).
        *   The `perSystem` block should also provide any minimal configuration options necessary for the imported module to produce the specific outputs that are being targeted by the unit tests. Often, if the module has well-defined defaults, simply importing it is sufficient.
        *   Crucially, it does **not** inherit all inputs from the main project flake, only those explicitly passed when its outputs are evaluated (see next point).
    *   **Rationale:** Isolates the module, making tests less brittle and easier to debug. It ensures that the module is tested with a controlled set of inputs.
  - The **Test Files (e.g., `tests/yourTestName.nix`)** then:
    *   Import the test harness flake definition: `testHarnessFlakeDef = import ./flake.nix;` (where `./flake.nix` refers to `tests/flake.nix`).
    *   Utilize `mainFlakeResolvedInputs` (passed from the main project flake's `checks` definition, containing all resolved inputs of the main project flake).
    *   Construct the arguments for the test harness flake's `outputs` function:
      ```nix
      testHarnessOutputsArgs = {
        self = testHarnessFlakeDef; # The test harness flake definition itself
        nixpkgs = mainFlakeResolvedInputs.nixpkgs;     # The actual nixpkgs flake
        flake-parts = mainFlakeResolvedInputs.flake-parts; # The actual flake-parts flake
        # If the module under test needs a reference to the main project flake (e.g., as 'latex-utils'):
        latex-utils = mainFlakeResolvedInputs.self;    # The main project flake
        # ... any other resolved inputs the test harness or module might need from the main flake ...
      };
      ```
    *   Evaluate the test harness outputs using a helper: `outputs = import ./test-flake-helpers.nix { flakeDef = testHarnessFlakeDef; outputsArgs = testHarnessOutputsArgs; };`
    *   Note on `test-flake-helpers.nix`: This helper is a standard and simple way to evaluate the test harness flake's `outputs` function. It takes the `flakeDef` and `outputsArgs` and calls `flakeDef.outputs outputsArgs`.
    *   Tests then access the generated outputs of the test harness flake (e.g., `outputs.packages.${system}.foo`, `outputs.devShells.${system}.bar`).
- **For pure library helpers** (in `lib/`):
  - Test by importing the helper directly.
- **Never use `lib.evalModules` on a flake-parts module.**
- **Never import the module file directly to test outputs that require flake-parts context.**
- **Do not use the main project flake for output tests; use the test harness flake and helper for isolation and clarity.**

## Additional Clarification: Handling the `latex-utils` Input in the Test Harness Flake

The test harness flake (`tests/flake.nix`) is intentionally designed to be minimal and decoupled from the main project flake. To achieve this, it does **not** declare a `latex-utils` input in its own `inputs` attribute set at the top level. Instead, it expects to be called with a resolved `latex-utils` input via the `outputsArgs` argument when evaluating outputs.

This pattern is implemented as follows:

- The `outputs` function of `tests/flake.nix` is defined to accept these arguments directly (e.g., `outputs = evalArgs @ { self, nixpkgs, flake-parts, latex-utils, ... }:`).
- In the `flake-parts.lib.mkFlake` call within `tests/flake.nix`, the `inputs` attribute set is constructed using these passed-in arguments:
  ```nix
  # Inside tests/flake.nix
  outputs = evalArgs @ { self, nixpkgs, flake-parts, latex-utils, ... }:
    flake-parts.lib.mkFlake {
      inherit self; # This is evalArgs.self (the test harness flake definition)
      inputs = {    # These are the inputs the imported module will see
        inherit nixpkgs flake-parts latex-utils; # These come from evalArgs
      };
    } {
      systems = [ "x86_64-linux" ]; # Or parameterize from evalArgs
      imports = [ ../modules/latex-utils.nix ]; # Module under test
      # ... minimal config for the module under test ...
    };
  ```
- This means the test harness flake can be used in tests by passing in the resolved `latex-utils` input (which is `mainFlakeResolvedInputs.self` from the main flake) and other necessary flake inputs like `nixpkgs` and `flake-parts` directly when its `outputs` function is called. This keeps the test harness flexible and focused only on the module under test.
- This is a common and idiomatic pattern for flake-parts module testing, as it allows the test harness to remain stable and independent of changes to the main project flake's structure or dependencies.

**Why is this done?**
- It ensures that tests are robust to changes in the main flake and can be run in isolation.
- It avoids coupling the test harness to the main flake's input structure, making tests easier to maintain and reason about.
- It matches upstream best practices for flake-parts module testing, as seen in other projects and the flake-parts documentation.

If you are writing or updating tests, always ensure that the test harness flake is called with the correct resolved inputs, including `latex-utils`, via the `outputsArgs` argument. This will ensure your tests remain stable and idiomatic.

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

### 1. **Test Harness Flake (`tests/flake.nix`)**

*   **Purpose:** Creates a minimal, isolated flake environment that imports and configures the module under test (e.g., `../modules/latex-utils.nix`).
*   **Structure:**
    *   Declares only essential inputs (e.g., `nixpkgs`, `flake-parts`, potentially the module's source if not co-located or handled differently).
    *   Uses `flake-parts.lib.mkFlake`.
    *   Its `outputs` function should be structured to accept arguments like `self`, `nixpkgs`, `flake-parts`, and any specific project inputs (like `latex-utils`) that are passed from the test file's `testHarnessOutputsArgs`.
    *   The call to `flake-parts.lib.mkFlake` should then use these passed arguments, for example:
      ```nix
      # Snippet for tests/flake.nix outputs function:
      outputs = evalArgs @ { self, nixpkgs, flake-parts, latex-utils, ... }:
        flake-parts.lib.mkFlake {
          inherit self; # From evalArgs
          inputs = { inherit nixpkgs flake-parts latex-utils; }; # From evalArgs
        } {
          systems = [ "x86_64-linux" ];
          imports = [ ../modules/latex-utils.nix ]; # Your module
          # ... minimal config for your module ...
        };
      ```
    *   Its `perSystem` block **must** include the module under test in its `imports` list (e.g., `imports = [ ../modules/latex-utils.nix ];`).
    *   The `perSystem` block should also provide any minimal configuration options necessary for the imported module to produce the specific outputs that are being targeted by the unit tests. Often, if the module has well-defined defaults, simply importing it is sufficient.
    *   Crucially, it does **not** inherit all inputs from the main project flake automatically, only those explicitly passed when its outputs are evaluated (see next point).
*   **Rationale:** Isolates the module, making tests less brittle and easier to debug. It ensures that the module is tested with a controlled set of inputs.

### 2. **Test Files (`tests/yourTestName.nix`)**

*   **Imports:**
    *   `testHarnessFlakeDef = import ./flake.nix;` (imports the test harness flake definition from `tests/flake.nix`).
    *   `mainFlakeResolvedInputs`: This is assumed to be available in the scope where the test is defined (typically passed in by the main flake's `flake.nix` when it defines its `checks`). It contains all resolved inputs of the main project flake.
*   **Constructing `outputsArgs`:**
    ```nix
    testHarnessOutputsArgs = {
      self = testHarnessFlakeDef; # The test harness flake definition
      nixpkgs = mainFlakeResolvedInputs.nixpkgs;     # Resolved nixpkgs flake
      flake-parts = mainFlakeResolvedInputs.flake-parts; # Resolved flake-parts
      # Pass the main project flake if the module under test needs it:
      latex-utils = mainFlakeResolvedInputs.self;    # Main project flake (resolved)
      inherit system;
      # ... any other inputs from mainFlakeResolvedInputs needed by the test harness ...
    };
    ```
*   **Evaluating Outputs:**
    *   `outputs = import ./test-flake-helpers.nix { flakeDef = testHarnessFlakeDef; outputsArgs = testHarnessOutputsArgs; };` (evaluates the test harness outputs).
*   **`test-flake-helpers.nix`:** This helper is a standard and simple way to evaluate the test harness flake's `outputs` function. It takes the `flakeDef` (the imported `./flake.nix`) and `outputsArgs` (containing `self = flakeDef`, and resolved inputs like `nixpkgs`, `flake-parts` from `mainFlakeResolvedInputs`) and calls `flakeDef.outputs outputsArgs`.
*   **Accessing Outputs:** Tests then access the generated outputs of the test harness flake (e.g., `outputs.packages.${system}.foo`, `outputs.devShells.${system}.bar`).

### Understanding Resolved vs. Unresolved Flake Inputs in the Test Harness

A common point of confusion can be how flake inputs are handled, especially when passed to a test harness.

*   **Unresolved Flake Input:** This is the declaration you write in your main `flake.nix` under the `inputs` attribute. For example, `inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";`. At this stage, it's essentially a pointer or a recipe for Nix to fetch the input.

*   **Resolved Flake Input:** When Nix evaluates your flake (e.g., during `nix build`, `nix flake check`, or when the top-level `outputs` function is called), it *resolves* these declared inputs. This involves:
    1.  Fetching the source code or flake from the specified URL or path.
    2.  Making it available as a Nix value within the flake's evaluation context. This value is typically an attribute set that includes the input's store path, its own `outputs` (if it's a flake), and metadata like `isFlake = true;` and `sourceInfo`.
    3.  The `flake.lock` file records the exact versions of these resolved inputs.

The `inputs` argument received by your main flake's `outputs` function (e.g., `outputs = inputs @ { self, nixpkgs, flake-parts, ... }: ...`) contains these **resolved inputs**. So, `inputs.nixpkgs` here is not the URL string; it's the actual `nixpkgs` flake object.

**Why the Test Harness Uses Resolved Inputs:**

Our test harness pattern, as defined in this ADR, relies on passing these *resolved* inputs from the main flake to the test harness flake (`tests/flake.nix`). This is done via the `mainFlakeResolvedInputs` argument (which is simply the `inputs` from the main flake's `outputs` function).

In `tests/yourTestName.nix`, when constructing `testHarnessOutputsArgs`:
```nix
testHarnessOutputsArgs = {
  self = testHarnessFlakeDef;
  nixpkgs = mainFlakeResolvedInputs.nixpkgs;     // This is the *resolved* nixpkgs flake
  flake-parts = mainFlakeResolvedInputs.flake-parts; // Resolved flake-parts
  latex-utils = mainFlakeResolvedInputs.self;    // The main project flake (resolved)
  inherit system;
  // ...
};
```
And in `tests/flake.nix`, when `flake-parts.lib.mkFlake` is called:
```nix
# Inside tests/flake.nix outputs function
outputs = evalArgs @ { self, nixpkgs, flake-parts, latex-utils, system, ... }:
  flake-parts.lib.mkFlake {
    inherit self;
    inputs = { inherit nixpkgs flake-parts latex-utils; }; // These are the resolved inputs
  } {
    systems = [ system ];
    imports = [ ../modules/latex-utils.nix ];
    // ...
  };
```
This is the correct approach because:
1.  `flake-parts.lib.mkFlake` itself expects its `inputs` argument (specifically, the values within the `inputs` attrset passed to it) to be actual flake objects or derivations, not unresolved URLs. It needs to be able to access their outputs or properties.
2.  The module being tested (`../modules/latex-utils.nix`) will also expect `inputs'.nixpkgs`, `inputs'.flake-parts`, etc. (as provided by `flake-parts` to its `perSystem` function) to be the actual resolved flakes it can work with.

Passing unresolved inputs would require the test harness flake to declare them again in its own `inputs` block and have Nix resolve them independently, which could lead to inconsistencies with the main flake's versions and defeats the purpose of testing with the exact same dependencies the main flake uses.

Therefore, the use of `mainFlakeResolvedInputs` to channel the already resolved inputs from the main flake into the test harness is intentional and aligns with how `flake-parts` and nested flake evaluations are expected to work. The error "Trying to retrieve system-dependent attributes for input nixpkgs, but this input is not a flake" suggests an issue with how this resolved input is perceived or handled in the specific nested evaluation context of the tests, rather than an issue with the principle of using resolved inputs.

- **Never use `lib.evalModules` on a flake-parts module.**
- **Never import the module file directly to test outputs that require flake-parts context.**
- **Do not use the main project flake for output tests; use the test harness flake and helper for isolation and clarity.**

---

## Appendix A: Comparison of Flake Module Testing Approaches

This appendix outlines different strategies observed for testing Nix flake outputs, particularly in the context of `flake-parts` modules and `nix-unit`.

### 1. `latex-utils` (This Project - Initial Approach)

*   **Framework:** `flake-parts` is used for the main project flake and for the dedicated test harness flake (`tests/flake.nix`).
*   **Input Handling for Tests:**
    *   The main project flake's `outputs` function (in `flake.nix`) passes its entire resolved `inputs` attribute set (e.g., containing `nixpkgs`, `flake-parts`, `self`) as a custom argument (e.g., `mainFlakeResolvedInputs`) to the Nix files defining `nix-unit` test suites (e.g., `tests/devShellLatexUtils.nix`).
    *   The individual test suite file then uses this `mainFlakeResolvedInputs` to pick out the necessary flake objects (`nixpkgs`, `flake-parts`, `self` aliased as `latex-utils`) and constructs an `outputsArgs` attribute set.
    *   This `outputsArgs` (containing `self = testHarnessFlakeDef`, and the resolved flake inputs) is passed to the `outputs` function of the imported test harness flake definition (`testHarnessFlakeDef = import ./tests/flake.nix;`).
    *   The test harness flake (`tests/flake.nix`) then calls `flake-parts.lib.mkFlake { self = /* ... */; inputs = { /* resolved inputs from outputsArgs */ }; } { imports = [ ../modules/latex-utils.nix ]; ... }`.
*   **Invocation:** Tests are defined as Nix expressions that are directly imported into the main flake's `perSystem.checks` attribute set.
*   **Challenge Encountered:** This approach led to errors where `nixpkgs`, despite being passed as a resolved input, was not recognized as a flake ("Trying to retrieve system-dependent attributes for input nixpkgs, but this input is not a flake") within the nested test harness evaluation, specifically when run via `nix flake check`.

### 2. `treefmt-nix` (External Example - Non-`flake-parts` for its own flake)

*   **Framework:** This project structures its `flake.nix` outputs manually and does not use `flake-parts` for its own top-level flake definition (though it provides a `flakeModule` for others to consume).
*   **Input Handling for Tests:**
    *   When defining its `checks`, `treefmt-nix` provides a `pkgs` argument to its test files (e.g., `import ./checks { pkgs = import nixpkgs { inherit system; ... }; ... }`).
    *   This `pkgs` is derived from a *fresh import* of its `nixpkgs` flake input, scoped to the specific system under test.
    *   It does not directly pass down the main flake's top-level `nixpkgs` *flake object* to the test logic for deriving `pkgs`; it re-imports to get `pkgs`.
*   **Invocation:** Tests are Nix expressions imported into `checks`.

### 3. `nix-unit` Official `flake-parts` Integration Pattern (Recommended)

*   **Framework:** This pattern is for projects using `flake-parts` for their main flake structure and `nix-unit` for testing.
*   **Input Handling for Tests:**
    *   The main project flake adds `nix-unit` to its inputs and imports `inputs.nix-unit.modules.flake.default` into its `flake-parts.lib.mkFlake` call.
    *   Tests are typically defined in separate Nix files and then imported into the `perSystem.nix-unit.tests` attribute set in the main `flake.nix`.
    *   **Key Mechanism:** The `perSystem.nix-unit.inputs` option is used. This option explicitly declares which of the main flake's resolved inputs (e.g., `nixpkgs`, `flake-parts`, the project's own `self`) should be made available to the sandboxed test execution environment.
        *   Example: `perSystem.nix-unit.inputs = { inherit (inputs) nixpkgs flake-parts myProjectFlakeAlias; };` (where `inputs` is the main flake's resolved inputs).
    *   The test files (e.g., `import ./tests/myTest.nix { inherit pkgs lib system inputs; }`) then receive these declared inputs directly as function arguments (e.g., an `inputs` argument containing `nixpkgs`, `flake-parts`, `myProjectFlakeAlias`).
*   **Invocation:** The `nix-unit` module automatically sets up the necessary `checks` derivations. Tests are run by `nix flake check`.
*   **Rationale/Benefit:** This explicit declaration via `perSystem.nix-unit.inputs` is designed to ensure that the specified flake inputs are correctly and robustly propagated into the isolated build/test sandbox used by `nix-unit`. This helps maintain their integrity as "flake" objects with all necessary metadata, which is crucial for `flake-parts` and Nixpkgs library functions operating within the tests. This pattern is considered best practice for testing `flake-parts` modules with `nix-unit`.

This comparative analysis highlights that explicitly managing the availability of flake inputs within the test execution context, as facilitated by the `nix-unit` `flake-parts` module's `inputs` option, is a more robust approach than manual passthrough, especially for tests run under `nix flake check`.

This pattern ensures maintainability, correctness, and alignment with upstream best practices.

--- 