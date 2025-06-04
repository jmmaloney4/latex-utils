# Unit Testing in latex-utils

> **Note:** The rationale and research for the flake-parts testing pattern used in this project is documented in [ADR 004](./decisions/004-flake-parts-testing-pattern.md). Please consult it for background and justification.

This project uses **nix-unit** for regression and property-based testing of Nix code. Tests are located in the `tests/` directory and are run via `nix flake check`.

## Types of Tests

- **Library/Helper Tests**: For pure Nix functions in `lib/`. These are written as Nix expressions that return an attribute set of `{ expr, expected }` pairs.
- **Flake-parts Module Output Tests**: For outputs like `devShells.full`, `build.unifiedTexShell`, etc. These must be tested by evaluating the outputs of a dedicated test harness flake (see below), not by using `lib.evalModules` or importing the module file directly.

## How to Write Tests

### 1. **Library Function Tests**

- Import the function directly from `lib/`.
- Write assertions as `{ expr = ...; expected = ...; }` or as plain boolean expressions.
- Example:

  ```nix
  { pkgs, lib }:
  let
    findLatexPackages = import ../lib/findLatexPackages.nix { inherit pkgs lib; };
  in {
    basic = {
      expr = builtins.attrNames (findLatexPackages { fileContents = "\\usepackage{foo,bar}"; });
      expected = ["bar" "foo"];
    };
  }
  ```

### 2. **Flake-parts Output Tests (with Test Harness Flake and Helper)**

- **Do NOT** use `lib.evalModules` on flake-parts modules.
- **Do NOT** import the module file directly for output tests.
- Instead, use the dedicated test harness flake at `tests/flake.nix` **and** the helper at `tests/test-flake-helpers.nix` to realize the outputs for a system:

  ```nix
  { pkgs, lib, ... }:
  let
    flake = import ./flake.nix;
    system = pkgs.stdenv.hostPlatform.system or "x86_64-linux";
    outputs = import ./test-flake-helpers.nix { inherit flake system; };
    fullShell = outputs.devShells.full;
  in {
    test_fullShell_is_package = lib.isDerivation fullShell;
  }
  ```

- The helper is necessary because the flake-parts outputs function expects more than just `system` (it also needs `self`, `nixpkgs`, `pkgs`, etc.). The helper ensures all required arguments are passed.
- For composable shell fragments, you can compose them in the test and assert on the result.
- The test harness flake provides a minimal, stable context for evaluating module outputs, ensuring tests are robust and isolated from changes in the main project flake.

### 3. **Understanding flake-parts, `perSystem`, and Test Harness Patterns**

#### What is `perSystem` in flake-parts?
- In a flake-parts flake, `perSystem` is **not** a top-level output. Instead, it is a configuration function or attribute set provided to `flake-parts.lib.mkFlake`.
- The outputs of your flake (such as `packages`, `devShells`, `apps`, etc.) are constructed by evaluating your `perSystem` function for each system in the `systems` list.
- **You do not access a top-level `perSystem` output.** Instead, you access outputs like `devShells.x86_64-linux.full`, `packages.x86_64-linux.default`, etc.
- This is confirmed by the [flake-parts template](https://github.com/hercules-ci/flake-parts/blob/main/template/default/flake.nix):
  ```nix
  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];
      perSystem = { config, self', inputs', pkgs, system, ... }: {
        packages.default = pkgs.hello;
      };
    };
  ```
- As shown, `perSystem` is a function argument, not an output.

#### Common Misconception
- If you see code or tests expecting a top-level `perSystem` output (e.g., `outputs.perSystem.x86_64-linux`), this is incorrect and will not work with flake-parts. Refactor such code to access the correct outputs as described above.

#### How to verify this in upstream code
- You can use gitingest to study the flake-parts source and template. For example:
  - To view the template: `gitingest hercules-ci/flake-parts template/default/flake.nix`
  - To view the README: `gitingest hercules-ci/flake-parts README.md`
- Look for how `perSystem` is used: always as a function argument, never as an output.

#### Correct Test Harness Pattern
- To test flake-parts module outputs, always use a dedicated test harness flake (e.g., `tests/flake.nix`) that calls `flake-parts.lib.mkFlake` and imports your module under test.
- The test harness flake should:
  - Declare only the minimal required inputs (`nixpkgs`, `flake-parts`, and your module).
  - Use `mkFlake` with a `systems` list and import your module in the `imports` list.
  - Optionally, provide minimal config in `perSystem` or `flake` as needed for your tests.
- In your test file, import this flake and access outputs like `outputs.devShells.x86_64-linux.full`.

#### Example (from flake-parts template):
```nix
outputs = inputs@{ flake-parts, ... }:
  flake-parts.lib.mkFlake { inherit inputs; } {
    systems = [ "x86_64-linux" ];
    imports = [ ../modules/latex-utils.nix ];
  };
```

#### Example (accessing outputs in a test):
```nix
let
  flake = import ./flake.nix;
  outputs = import ./test-flake-helpers.nix { inherit flake system; };
  fullShell = outputs.devShells.full;
in {
  test_fullShell_is_package = lib.isDerivation fullShell;
}
```

#### References
- See [ADR 004](./decisions/004-flake-parts-testing-pattern.md) for rationale and research.
- See [flake-parts template](https://github.com/hercules-ci/flake-parts/blob/main/template/default/flake.nix) for canonical usage.

### 4. **General Guidelines**

- Place all tests in the `tests/` directory.
- Use descriptive attribute names for each test.
- For tests that should only run on Linux (not Darwin), use a conditional on `pkgs.stdenv.isDarwin`.
- If you need to test a function that expects a flake-parts context, always go through the test harness flake outputs using the helper.

## Running Tests

Run all tests with:

```sh
nix flake check
```

Or, to run the nix-unit tests for the current system (recommended):

```sh
nix build .#checks.$(nix eval --raw --impure --expr builtins.currentSystem).nix-unit -L
```

This will build and run the nix-unit test suite for your current system.

## Troubleshooting

- **"The option `perSystem` does not exist"**: You are trying to use `lib.evalModules` on a flake-parts module. Rewrite your test to access outputs from the test harness flake using the helper as shown above.
- **"function 'outputs' called without required argument 'nixpkgs'"**: You are calling the outputs function without all required arguments. Use the helper to pass all necessary arguments.
- **Infinite recursion**: This can happen if you try to build a derivation that depends on the flake's own outputs. Avoid circular dependencies in tests.

## See Also

- [ARCHITECTURE.md](./ARCHITECTURE.md) for module structure and API.
- [flake-parts documentation](https://flake.parts/) for more on flake-parts modules.
- [nix-unit documentation](https://github.com/nix-community/nix-unit) for test syntax and features.

> **WARNING:**
> In the flake-parts ecosystem, `perSystem` is **never** an output. It is a function (or attribute set) provided to `flake-parts.lib.mkFlake` that is called internally for each system. You should **never** use, produce, or access a `perSystem` output. All outputs like `devShells`, `packages`, etc. are produced by flake-parts by calling your `perSystem` function for each system and collecting the results under the appropriate output attributes. 