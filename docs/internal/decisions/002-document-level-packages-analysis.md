# ADR 002: Document-Level Package Collection Analysis and UX Improvements
*Date:* 2025-06-03  
*Status:* accepted

## Context

A user reported that document-level `extraTexPackages` are not included in the unified TeX environment (`texlive-unified`, `latexmk-unified`) used for IDE integration, causing "File 'packagename.sty' not found" errors in IDEs. This issue was reported as a high-priority bug affecting the core value proposition of latex-utils.

After comprehensive analysis including:
- Code review of the collection logic in `modules/latex-utils.nix`
- Creating test cases in `tests/document-level-packages.nix`
- Tracing the data flow from documents → processing → unified environment
- Testing with actual TeX Live package resolution

## Decision

The collection logic is **working correctly**. Document-level `extraTexPackages` **are** properly included in the unified environment. The real issue is **user experience around invalid package names** and **error handling**.

**Root cause identified:** Users specify invalid TeX Live package names (e.g., `algorithm` instead of `algorithms`), which causes either:
1. Build failures with cryptic error messages, or
2. Packages being silently excluded from the unified environment

**Solution:** Maintain the current (correct) collection logic and improve user experience by:
1. Adding package name validation with helpful suggestions
2. Improving error messages for common mistakes
3. Adding documentation about TeX Live vs LaTeX package names

## Alternatives Considered

1. **Rewrite collection logic** – Analysis showed the current logic is correct, so this would be unnecessary and potentially introduce bugs.

2. **Silent fallback for invalid packages** – This would hide user errors and make debugging harder.

3. **Current approach** (chosen) – Fix the UX issues while preserving the correct underlying logic.

## Consequences

- **Pros:**  
  - Collection logic remains correct and well-tested
  - Users get better error messages for common mistakes
  - Documentation prevents future confusion
  - Maintains backward compatibility

- **Cons:**  
  - Requires additional validation logic
  - Need to maintain mapping of common LaTeX→TeX Live package names

## Implementation Plan

1. ✅ **Analysis complete** - Confirmed collection logic works correctly
2. ✅ **Test coverage added** - `tests/document-level-packages.nix` validates the behavior
3. 🔄 **UX improvements** (future work):
   - Add package name validation with suggestions in `lib/normalizeExtraTexPackages.nix`
   - Improve error messages for missing packages
   - Add documentation about common package name issues
4. 🔄 **Documentation updates** (future work):
   - Add troubleshooting guide for package name issues
   - Examples of common LaTeX vs TeX Live package name differences

## Evidence

Test results confirm document-level packages are correctly included:
```nix
# Test shows all document-level packages are collected:
unifiedPackagesList.expr = ["algorithms" "amsmath" "enumitem" "tikzposter"]
# Where:
# - "amsmath" = module-level package
# - "algorithms", "enumitem", "tikzposter" = document-level packages
```

The unified environment successfully builds and contains all expected packages from both module-level and document-level `extraTexPackages`. 