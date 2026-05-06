# 004: Testing flake-parts Modules with nix-unit

**Status:** Accepted\
**Date:** 2025-06-03\
**Author:** o4-mini (AI agent)

______________________________________________________________________

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

  - Always test by leveraging the **`nix-unit` integration with `flake-parts`**. This involves:
    1. **Main Flake Configuration (`flake.nix`):**

       - Import `inputs.nix-unit.modules.flake.default` into your `flake-parts.lib.mkFlake` call.
       - **Crucially, use `perSystem.nix-unit.inputs` to explicitly declare which of the main flake's resolved inputs should be passed to the test environment.** This is the key to ensuring inputs like `nixpkgs`, `flake-parts`, and the project's own `self` (often aliased, e.g., as `latex-utils`) are correctly propagated as flake objects.
         ```nix
         # In your main flake.nix
         outputs = flakeInputs @ { flake-parts, nix-unit, systems, ... }:
           flake-parts.lib.mkFlake { inputs = flakeInputs; } {
             systems = import systems;
             imports = [ flakeInputs.nix-unit.modules.flake.default /* ...other imports */ ];
             perSystem = { config, pkgs, lib, system, inputs', ... }: { # Note: `inputs` (no prime) here is the perSystem one
               nix-unit = {
                 inputs = { # These are the inputs made available to test files
                   inherit (flakeInputs) nixpkgs flake-parts; # From main flake's resolved inputs
                   latex-utils = flakeInputs.self; # Main flake's self, aliased
                 };
                 tests = {
                   # Import your test files directly
                   myAwesomeTest = import ./tests/myAwesomeTest.nix;
                   anotherTest = import ./tests/anotherTest.nix;
                 };
               };
               # ... other perSystem config ...
             };
           };
         ```
       - **Important Note on Input Naming:** To avoid ambiguity with the `inputs` argument provided by `flake-parts` to the `perSystem` function, it's recommended to name the main flake's top-level `outputs` argument distinctively (e.g., `flakeInputs` as shown above, previously `inputsOuter`). This ensures that when you specify `inherit (flakeInputs) nixpkgs;` within `perSystem.nix-unit.inputs`, you are unambiguously referring to the main flake's resolved inputs.

    2. **Test Files (e.g., `tests/myAwesomeTest.nix`):**

       - These files should be authored as functions that accept the standard `nix-unit` arguments, including `pkgs`, `lib`, `system`, and importantly, an `inputs` argument. This `inputs` argument will be an attribute set containing the flake inputs you declared in `perSystem.nix-unit.inputs` (e.g., `inputs.nixpkgs`, `inputs.flake-parts`, `inputs.latex-utils`).
         ```nix
         # In tests/myAwesomeTest.nix
         { pkgs, lib, system, inputs, ... }: let
           # Test Harness Flake (still recommended for isolating module evaluation)
           testHarnessFlakeDef = import ./flake.nix; # (tests/flake.nix)

           testHarnessOutputsArgs = {
             self = testHarnessFlakeDef;
             # Source these from the `inputs` argument provided by nix-unit
             nixpkgs = inputs.nixpkgs;
             flake-parts = inputs.flake-parts;
             latex-utils = inputs.latex-utils; # Or whatever you named your project's self
             inherit system;
           };

           # Evaluate the test harness outputs
           # test-flake-helpers.nix remains useful
           testOutputs = import ./test-flake-helpers.nix {
             flakeDef = testHarnessFlakeDef;
             outputsArgs = testHarnessOutputsArgs;
           };
         in {
           # Your actual test assertions using testOutputs
           someTest = lib.isDerivation testOutputs.packages.${system}.somePackage;
           devShellTest = testOutputs.devShells.${system}.default.name == "my-dev-shell";
         }
         ```

    3. **Test Harness Flake (`tests/flake.nix`):**

       - The role of a dedicated test harness flake remains highly recommended.
       - **Purpose:** Creates a minimal, isolated `flake-parts` environment that imports and configures only the module(s) under test (e.g., `../modules/latex-utils.nix`).
       - **Structure:**
         - Declares its own minimal `inputs` if it needs to fetch them independently (e.g., fixed versions of `nixpkgs`, `flake-parts` for extreme isolation, though typically it will receive these).
         - Its `outputs` function should accept these as arguments (e.g., `evalArgs @ { self, nixpkgs, flake-parts, latex-utils, system, ... }`).
         - The call to `flake-parts.lib.mkFlake` uses these passed arguments, for example:
         ```nix
         # Snippet for tests/flake.nix outputs function:
         outputs = evalArgs @ { self, nixpkgs, flake-parts, latex-utils, system, ... }:
           flake-parts.lib.mkFlake {
             inherit self; # From evalArgs.self
             inputs = { inherit nixpkgs flake-parts latex-utils; }; # From evalArgs, to be used as inputs'.<name> by the module
           } {
             systems = [ system ]; # Use system from evalArgs
             imports = [
               # Example: if latex-utils is the module source passed in:
               latex-utils.flakeModule # Or a direct path: ../modules/latex-utils.nix
             ];
             # ... minimal config for your module ...
           };
         ```
       - **Rationale:** Isolates the module, making tests less brittle and easier to debug. It ensures that the module is tested with a controlled set of inputs, which are now reliably provided via `nix-unit`.

- **For pure library helpers** (in `lib/`):

  - Test by importing the helper directly. These tests typically only need `pkgs` and `lib`.

- **Never use `lib.evalModules` on a flake-parts module.**

- **Never import the module file directly to test outputs that require flake-parts context.**

- **Do not use the main project flake for output tests; use the test harness flake and helper for isolation and clarity.** This is still true, but the *inputs* to that harness are now reliably provided by `nix-unit`.

## Additional Clarification: Handling the `latex-utils` Input in the Test Harness Flake

The test harness flake (`tests/flake.nix`) is intentionally designed to be minimal and decoupled from the main project flake. It receives its necessary *flake inputs* (like `nixpkgs`, `flake-parts`, and the `latex-utils` flake object itself) via the `outputsArgs` passed to its `outputs` function. These `outputsArgs` are constructed in the individual test files (e.g., `tests/myAwesomeTest.nix`) using the `inputs` argument injected by `nix-unit`.

This pattern is implemented as follows:

- The `outputs` function of `tests/flake.nix` is defined to accept these arguments directly (e.g., `outputs = evalArgs @ { self, nixpkgs, flake-parts, latex-utils, system, ... }:`).
- In the `flake-parts.lib.mkFlake` call within `tests/flake.nix`, the `inputs` attribute set (which `flake-parts` uses to provide `inputs'.<name>` to modules) is constructed using these passed-in arguments:
  ```nix
  # Inside tests/flake.nix
  outputs = evalArgs @ { self, nixpkgs, flake-parts, latex-utils, system, ... }:
    flake-parts.lib.mkFlake {
      inherit self; # This is evalArgs.self (the test harness flake definition)
      inputs = {    # These are the inputs the imported module will see as `inputs'.<name>`
        inherit nixpkgs flake-parts latex-utils; # These come from evalArgs
      };
    } {
      systems = [ system ]; # Or parameterize from evalArgs
      imports = [
        # Example: if latex-utils is the module source passed in:
        latex-utils.flakeModule # Or a direct path: ../modules/latex-utils.nix
      ];
      # ... minimal config for the module under test ...
    };
  ```
- This means the test harness flake (`tests/flake.nix`) is called from a test file (e.g., `tests/myAwesomeTest.nix`) with `nixpkgs`, `flake-parts`, and `latex-utils` that were originally sourced from the main flake's resolved inputs and correctly passed into the test file by `nix-unit`.

**Why is this done?**

- It ensures that tests are robust and use the exact same dependency versions as the main flake.
- The `perSystem.nix-unit.inputs` mechanism is the idiomatic way to ensure flake inputs retain their integrity (e.g., `isFlake = true;` metadata) when passed into the test sandbox, which was the root cause of the "not a flake" error with previous manual passthrough methods.
- It keeps the test harness focused only on the module under test, while `nix-unit` handles the reliable delivery of its flake dependencies.

If you are writing or updating tests, always ensure that:

1. Your main `flake.nix` uses `perSystem.nix-unit.inputs` to declare all flake inputs needed by your tests.
2. Your test files (`tests/*.nix`) are functions accepting an `inputs` argument (among others like `pkgs`, `lib`, `system`) from which they will source these flake inputs.
3. These sourced inputs are then passed to your test harness flake (`tests/flake.nix`) when its `outputs` are evaluated.

This will ensure your tests remain stable, idiomatic, and correctly interact with the `flake-parts` and `nix-unit` ecosystems.

## Consequences

- Test files for flake-parts outputs will correctly receive flake inputs via `nix-unit`'s `inputs` argument.
- The test harness flake (`tests/flake.nix`) and helper (`tests/test-flake-helpers.nix`) remain essential for evaluating module outputs in an isolated `flake-parts` environment.
- Pure library tests will continue to import helpers directly.
- Documentation (`docs/unit-testing.md`) will reference this ADR, the test harness flake, and the helper for future contributors, emphasizing the `perSystem.nix-unit.inputs` pattern.
- This pattern ensures maintainability, correctness, and alignment with upstream best practices, and resolves previous "not a flake" errors.

## References

- [flake-parts documentation](https://flake.parts/)
- [nix-unit documentation](https://github.com/nix-community/nix-unit)
- [latex-utils docs/unit-testing.md](../unit-testing.md)
- [tests/test-flake-helpers.nix](../tests/test-flake-helpers.nix)

### 1. **Test Harness Flake (`tests/flake.nix`)**

- **Purpose:** Creates a minimal, isolated flake environment that imports and configures the module under test (e.g., `../modules/latex-utils.nix`). This structure remains valuable.
- **Structure:**
  - Declares its own minimal `inputs` if it needs to fetch them independently (e.g., fixed versions of `nixpkgs`, `flake-parts` for extreme isolation, though typically it will receive these).
  - Its `outputs` function should be structured to accept arguments like `self`, `nixpkgs`, `flake-parts`, `system`, and any specific project inputs (like `latex-utils`) that are passed from the test file's `testHarnessOutputsArgs`.
  - The call to `flake-parts.lib.mkFlake` should then use these passed arguments, for example:
  ```nix
  # Snippet for tests/flake.nix outputs function:
  outputs = evalArgs @ { self, nixpkgs, flake-parts, latex-utils, system, ... }:
    flake-parts.lib.mkFlake {
      inherit self; # From evalArgs.self
      inputs = { inherit nixpkgs flake-parts latex-utils; }; # From evalArgs, to be used as inputs'.<name> by the module
    } {
      systems = [ system ]; # Use system from evalArgs
      imports = [
        # Example: if latex-utils is the module source passed in:
        latex-utils.flakeModule # Or a direct path: ../modules/latex-utils.nix
      ];
      # ... minimal config for your module ...
    };
  ```
- **Rationale:** Isolates the module, making tests less brittle and easier to debug. It ensures that the module is tested with a controlled set of inputs, which are now reliably provided via `nix-unit`.

### 2. **Test Files (`tests/yourTestName.nix`)**

- **Function Signature:** Must accept `inputs` as an argument, which `nix-unit` populates based on `perSystem.nix-unit.inputs` in the main `flake.nix`.
  ```nix
  # In tests/yourTestName.nix
  { pkgs, lib, system, inputs, ... }: # 'inputs' is key!
  let
    # ...
  in
  {
    # ... tests ...
  }
  ```
- **Constructing `testHarnessOutputsArgs`:**
  ```nix
  testHarnessOutputsArgs = {
    self = testHarnessFlakeDef; # The test harness flake definition
    nixpkgs = inputs.nixpkgs;     # Sourced from nix-unit injected 'inputs'
    flake-parts = inputs.flake-parts; # Sourced from nix-unit injected 'inputs'
    latex-utils = inputs.latex-utils; # Sourced from nix-unit injected 'inputs' (main project flake)
    inherit system; # Pass the system argument to the test harness
    # ... any other non-flake args the test harness might need ...
  };
  ```
- **Evaluating Outputs:**
  - `evaluatedTestOutputs = import ./test-flake-helpers.nix { flakeDef = testHarnessFlakeDef; outputsArgs = testHarnessOutputsArgs; };`
- **`test-flake-helpers.nix`:** This helper remains useful. It takes the `flakeDef` (the imported `./flake.nix`) and `outputsArgs` and calls `flakeDef.outputs outputsArgs`.
- **Accessing Outputs:** Tests then access the generated outputs of the test harness flake (e.g., `evaluatedTestOutputs.packages.${system}.foo`).

### Understanding Resolved vs. Unresolved Flake Inputs (and `nix-unit`)

A common point of confusion can be how flake inputs are handled, especially when passed to a test harness. The `perSystem.nix-unit.inputs` mechanism is designed to correctly handle **resolved flake inputs**.

- **Unresolved Flake Input:** This is the declaration you write in your main `flake.nix` under the `inputs` attribute (e.g., `inputs.nixpkgs.url = "...";`). It's a pointer.

- **Resolved Flake Input:** When Nix evaluates your flake, it *resolves* these declared inputs, fetching them and making them available as Nix values (attribute sets with `isFlake = true;`, `sourceInfo`, `outputs`, etc.). The argument to your main flake's `outputs` function (e.g., `flakeInputs` in `outputs = flakeInputs @ { ... }`) contains these resolved inputs.

**Why the `perSystem.nix-unit.inputs` Pattern is Correct:**
