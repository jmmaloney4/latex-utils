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

### 3. **General Guidelines**

- Place all tests in the `tests/` directory.
- Use descriptive attribute names for each test.
- For tests that should only run on Linux (not Darwin), use a conditional on `pkgs.stdenv.isDarwin`.
- If you need to test a function that expects a flake-parts context, always go through the test harness flake outputs using the helper.

## Running Tests

Run all tests with:

```sh
nix flake check
```

Or, to run a specific test suite:

```sh
nix build .#checks.x86_64-linux.nix-unit
```

## Troubleshooting

- **"The option `perSystem` does not exist"**: You are trying to use `lib.evalModules` on a flake-parts module. Rewrite your test to access outputs from the test harness flake using the helper as shown above.
- **"function 'outputs' called without required argument 'nixpkgs'"**: You are calling the outputs function without all required arguments. Use the helper to pass all necessary arguments.
- **Infinite recursion**: This can happen if you try to build a derivation that depends on the flake's own outputs. Avoid circular dependencies in tests.

## See Also

- [ARCHITECTURE.md](./ARCHITECTURE.md) for module structure and API.
- [flake-parts documentation](https://flake.parts/) for more on flake-parts modules.
- [nix-unit documentation](https://github.com/nix-community/nix-unit) for test syntax and features. 