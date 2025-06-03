# Change Log

## Fixes and Improvements (Latest)

### New Features

#### Module-Level `extraTexPackages`
- Added `latex-utils.extraTexPackages` option at the module level
- Packages specified here are included in ALL documents, the unified TeX environment, and dev shells
- Supports the same flexible input types as document-level `extraTexPackages` (strings, derivations, functions)
- Document-level packages are merged with module-level packages (document-level takes precedence)
- Works even without any documents configured, creating a useful TeX environment

### Bug Fixes

#### 1. Fixed Package Type Error for `vscode-settings-with-overrides`
- **Issue**: Function was incorrectly exposed as a package, causing flake evaluation errors
- **Fix**: Removed from packages attrset completely
- **Impact**: Flake now evaluates correctly without type errors

#### 2. Fixed Double-Normalization of `extraTexPackages`
- **Issue**: Module pre-normalized packages, then `mkLatexPdfDocument` tried to normalize again, causing errors
- **Fix**: Pass pre-normalized packages under `_preNormalizedExtraPackages` parameter to avoid re-processing
- **Impact**: `extraTexPackages` now works correctly with all input types

#### 3. Improved devShells Resilience
- **Issue**: devShells disappeared entirely if document processing failed
- **Fix**: Always provide devShells with informative fallback messages
- **Impact**: Better user experience during configuration errors

#### 4. Enhanced Error Handling
- **Issue**: Missing or failing files during package discovery had poor error messages
- **Fix**: Added error context and warnings for missing files
- **Impact**: Easier debugging of LaTeX package discovery issues

### API Improvements

#### VSCode Settings Custom App
- A new app `vscode-settings-custom` is available for generating custom VSCode settings
- Usage:
  ```bash
  nix run .#vscode-settings-custom -- '{"ltex.language": "de-DE"}'
  ```
- This generates a `settings.json` file with your custom overrides merged with the default LaTeX settings

### Internal Improvements

- Better separation of concerns between module-level and document-level processing
- Clearer parameter passing to avoid ambiguity
- More consistent package merging logic
- Improved unified environment creation that works with module-level packages alone 