# ADR 014: Lazy Source Scanning in mkLatexPdfDocument

*Date:* 2026-05-06
*Status:* proposed

## Context

`mkLatexPdfDocument` performs source scanning at Nix evaluation time. It string-interpolates `src` to form a filesystem path, then calls `findLatexFiles` (which uses `builtins.readDir`) and `findLatexPackages` (which uses `builtins.readFile`) to discover `\usepackage{}` directives. This scanning happens unconditionally, even when the caller provides pre-normalized packages via `_preNormalizedExtraPackages`.

This causes sandbox failures on Linux CI. When `src` is a derivation (e.g., `writeTextDir`), interpolating `"${src}"` forces the derivation to realize during evaluation. The strict Linux sandbox prevents this, so tests that create `.tex` files via `writeTextDir` and pass them to `mkLatexPdfDocument` fail on CI. The same tests pass on macOS, where the sandbox is more permissive.

Currently, 16 tests in `extraTexPackages.nix` and `unifiedTexLive.nix` fail on CI for this reason. They are skipped entirely on Darwin.

The module system (`document-processing.nix`) already does its own source scanning and passes pre-normalized packages to `mkLatexPdfDocument` via `_preNormalizedExtraPackages`. When this parameter is provided, the scanning inside `mkLatexPdfDocument` is redundant -- its `discovered` result is computed but then overridden by `_preNormalizedExtraPackages` in `extraTexPackagesAttrs`. The scanning result feeds into `allPackages` via `// discovered`, but since `_preNormalizedExtraPackages` also gets merged in, and the module system already merges discovered packages with extras before passing them, the `discovered` from `mkLatexPdfDocument`'s own scanning is always a subset of what `_preNormalizedExtraPackages` provides.

## Decision

Guard source scanning in `mkLatexPdfDocument` so it only runs when `_preNormalizedExtraPackages` is not provided. When pre-normalized packages are present, set `discovered = {}` and skip `findLatexFiles`/`findLatexPackages` entirely.

Then rewrite the failing tests into two pure-eval layers that don't require source filesystem access:

1. **Scanning tests**: Call `findLatexPackages` directly with string content (no filesystem). Assert the correct packages are extracted from `\usepackage{}` and `% CTAN:` directives.
2. **Integration tests**: Call `mkLatexPdfDocument` with `_preNormalizedExtraPackages` (bypassing scanning). Inspect derivation attributes (e.g., `nativeBuildInputs`, `name`) to confirm packages are wired into the build environment.

### Why the guard doesn't break existing behavior

There are exactly two call sites for `mkLatexPdfDocument`:

**Call site 1: `document-processing.nix` (module system)**
This is the primary caller. Lines 98-112 show it computes its own scanning (lines 26-46), normalizes packages, merges module-level and document-level extras, then passes the result as `_preNormalizedExtraPackages`. After the guard, `mkLatexPdfDocument` skips its redundant scanning. The final `allPackages` attrset is computed as:

```nix
allPackages = { base packages... } // discovered // texPackages // extraTexPackagesAttrs;
```

Before the guard: `discovered` contains packages found by `mkLatexPdfDocument`'s own scan, `extraTexPackagesAttrs` equals `_preNormalizedExtraPackages`. The module already merged `discovered` into `_preNormalizedExtraPackages`, so `discovered` is a strict subset of `extraTexPackagesAttrs`. The `//` merge is right-biased, so `discovered` is overridden by `extraTexPackagesAttrs` for overlapping keys. Non-overlapping keys from `discovered` would be packages the module found but didn't include -- but the module's scanning uses the same `findLatexFiles`/`findLatexPackages` functions on the same `src`, so they always produce identical results.

After the guard: `discovered = {}`, `extraTexPackagesAttrs` unchanged. The merge produces the same result because the non-overlapping portion of `discovered` was empty in practice.

**Call site 2: Direct `callPackage` (tests, standalone usage)**
When called directly without `_preNormalizedExtraPackages`, the guard is not triggered. Scanning runs as before. No behavior change.

## Alternatives Considered

1. **Defer scanning to build time** -- Move source scanning into the builder script so it runs at build time, not eval time. This would eliminate the eval-time realization entirely and allow arbitrary `src` derivations. Rejected because it requires a substantial rewrite of the scanning logic (currently pure Nix, would need to become a shell script that outputs Nix-compatible data) and changes the interface contract.

2. **Use `builtins.toFile` in tests** -- Replace `writeTextDir` with `builtins.toFile`, which produces a store path without creating a derivation. Rejected because `builtins.toFile` produces a single file, not a directory. `mkLatexPdfDocument` expects `src` to be a directory (it forms `"${src}/${workingDirectory}"`). Would require either changing `mkLatexPdfDocument`'s interface or wrapping the file in a directory, which brings back the derivation problem.

3. **Keep skipping tests on CI** -- The status quo. Rejected because it means the tests never actually validate the code on the platform where it runs in production.

## Consequences

- **Pros:**

  - All tests pass on both macOS and Linux CI
  - Tests validate scanning logic and package wiring independently
  - `mkLatexPdfDocument` is cheaper to evaluate when called through the module system (avoids redundant filesystem traversal)
  - Removes the `isAarch64Darwin`/`isDarwin` skip hacks from test files

- **Cons:**

  - End-to-end path (scanning feeds into derivation construction) is no longer tested in a single test. This path is just `//` merging two attrsets, so the risk is low.
  - Tests that use `_preNormalizedExtraPackages` don't validate that scanning produces the same packages the test hardcodes. This is mitigated by having separate scanning tests that validate the same content.

## Technical Details

### Guard implementation in `lib/mkLatexPdfDocument.nix`

```nix
# Before (unconditional scanning):
searchPaths = findLatexFiles {basePath = "${src}/${workingDirectory}";};
discovered = builtins.foldl' ... (map (p: ... builtins.readFile p ...) searchPaths);

# After (conditional scanning):
discovered =
  if args ? _preNormalizedExtraPackages
  then {}
  else let
    searchPaths = findLatexFiles {basePath = "${src}/${workingDirectory}";};
  in
    builtins.foldl' (a: b: a // b) {}
    (map (p:
      if (builtins.pathExists p)
      then findLatexPackages {fileContents = builtins.readFile p;}
      else {}
    ) (pkgs.lib.lists.unique searchPaths));
```

### Test structure

```
tests/
  findLatexPackages.nix     # NEW: scanning tests (pure string inputs)
  extraTexPackages.nix       # REWRITTEN: integration tests (pre-normalized packages)
  unifiedTexLive.nix         # REWRITTEN: integration tests (pre-normalized packages)
```

## Supersedes / Dependencies

- supersedes: `003-skip-readDir-tests-on-darwin.md`, `006-disable-extraTexPackages-test-on-aarch64-darwin.md`
- depends on: `001-module-level-packages-and-bug-fixes.md` (introduced `_preNormalizedExtraPackages`)
