# ADR 001: Module-Level extraTexPackages and Core Bug Fixes

*Date:* 2025-06-03\
*Status:* accepted

## Context

The latex-utils module had several critical issues that prevented normal usage:

1. **Function in packages attrset**: `vscode-settings-with-overrides` was exposed as a function rather than a derivation, causing flake evaluation errors
2. **Double-normalization bug**: The module pre-normalized `extraTexPackages`, but `mkLatexPdfDocument` attempted to normalize them again, causing type errors
3. **Fragile devShells**: Development shells would disappear entirely if document processing failed, providing no fallback
4. **Poor error handling**: Missing files during package discovery had unclear error messages
5. **Package duplication**: Users had to specify common packages (like `amsmath`, `geometry`) in every document, violating DRY principles

Additionally, there was a need for module-level package configuration to support common use cases like research groups, course materials, and multi-document projects where many documents share a common package set.

## Decision

We implemented a comprehensive solution addressing all identified issues:

1. **Added module-level `extraTexPackages` option** that applies to ALL documents, the unified TeX environment, and dev shells
2. **Fixed double-normalization** by passing pre-normalized packages under `_preNormalizedExtraPackages` parameter
3. **Removed function from packages attrset** and provided alternative access methods
4. **Made devShells resilient** with informative fallback messages
5. **Enhanced error handling** with better context and warnings

The module-level `extraTexPackages` supports the same flexible input formats as document-level (strings, derivations, functions) and merges correctly with document-specific packages.

## Alternatives Considered

1. **Option A: Fix bugs only, no module-level feature** – Would address immediate issues but not the DRY problem users face
2. **Option B: Separate module for common packages** – Would require additional complexity and multiple imports
3. **Option C: Module-level + document-level merge** (chosen) – Provides both DRY benefits and per-document flexibility

## Consequences

- **Pros:**

  - Eliminates package duplication across documents (DRY principle)
  - Provides fallback behavior for better user experience
  - Fixes all identified blocking bugs
  - Maintains backward compatibility
  - Supports complex use cases (research groups, course materials)
  - Clear error messages improve debugging experience
  - Unified environment includes all packages from all sources
  - Works even without documents configured

- **Cons:**

  - Slightly more complex internal logic for package merging
  - Additional option increases API surface area
  - Module evaluation is now required even for simple use cases

## Implementation Details

### Package Merging Strategy

```nix
# Module-level packages normalized once
moduleExtraPackagesNormalized = normalizeHelpers.normalizeExtraTexPackages {
  extraTexPackages = moduleExtraTexPackages;
  discoveredPackages = {};  # No discovered packages at module level
};

# Document-level packages normalized per document
docExtraPackagesNormalized = normalizeHelpers.normalizeExtraTexPackages {
  extraTexPackages = doc.extraTexPackages;
  discoveredPackages = discovered;
};

# Merge with document-level taking precedence
mergedExtraPackages = moduleExtraPackagesNormalized // docExtraPackagesNormalized;
```

### Double-Normalization Fix

Pass pre-normalized packages to avoid re-processing:

```nix
mkLatexPdfDocument (doc // {
  _preNormalizedExtraPackages = extraPackagesForDoc;
  # Don't pass extraTexPackages raw
});
```

### Resilient devShells

Always provide devShells with informative messages:

```nix
devShells.latex-utils =
  if hasAnyConfig && vscodeIntegration ? vscode-devshell
  then vscodeIntegration.vscode-devshell
  else fallbackShellWithHelpfulMessage;
```

## Supersedes / Dependencies

- supersedes: N/A (first major architectural change)
- depends on: existing `normalizeExtraTexPackages` function
