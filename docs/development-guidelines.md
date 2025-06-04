# Development Guidelines for latex-utils

## ⚠️ How to Test Flake Outputs in This Repository

This project uses [flake-parts](https://github.com/hercules-ci/flake-parts) modules, **not** NixOS modules. This means:

- **All outputs you want to test (e.g., `build.unifiedTexShell`, `devShells.full`) are flake outputs, not NixOS module options.**
- **Do NOT use `lib.evalModules` or the NixOS module system in your tests.**
- **To test outputs, you must evaluate the flake as a flake, passing the correct resolved inputs.**

### Test Harness Pattern

1. **Test Harness Flake (`tests/flake.nix`):**
    - Declares only the inputs it needs (e.g., `nixpkgs`, `flake-parts`).
    - Uses `flake-parts.lib.mkFlake` to construct outputs, importing the module under test.
    - Example:
      ```nix
      {
        inputs = {
          nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
          flake-parts.url = "github:hercules-ci/flake-parts";
        };
        outputs = outputsArgs @ { flake-parts, nixpkgs, ... }:
          flake-parts.lib.mkFlake {
            self = outputsArgs.self;
            inputs = {
              inherit (outputsArgs) nixpkgs flake-parts;
            };
          } {
            systems = ["x86_64-linux"];
            imports = [ ../modules/latex-utils.nix ];
          };
      }
      ```
2. **Test Files (`tests/devShellFragments.nix`, etc.):**
    - Import the test harness flake and call its `outputs` function with a set containing `self`, `nixpkgs`, and `flake-parts` (resolved from the main flake's inputs).
    - Example:
      ```nix
      let
        flake = import ./flake.nix;
        testHarnessOutputsArgs = {
          self = flake;
          nixpkgs = mainFlakeResolvedInputs.nixpkgs;
          flake-parts = mainFlakeResolvedInputs.flake-parts;
        };
        outputs = import ./test-flake-helpers.nix {
          flakeDef = flake;
          outputsArgs = testHarnessOutputsArgs;
        };
      in {
        # Now you can access outputs.build.unifiedTexShell, outputs.devShells.full, etc.
      }
      ```

**If you do not follow this pattern, you will get errors like `attribute 'build' missing` or `attribute 'full' missing` in your tests.**

---

# (rest of development guidelines follow) 