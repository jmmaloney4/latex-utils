# ADR-008: Modularize Large latex-utils.nix Module

## Status

Accepted

## Context

The current `modules/latex-utils.nix` file has grown to 506 lines and contains multiple distinct concerns that would benefit from separation. This large file makes maintenance, testing, and understanding more difficult for both human contributors and LLM agents.

### Current File Analysis

The current `latex-utils.nix` contains several distinct functional areas:

1. **Type Definitions** (lines 7-62): Custom NixOS module types for `extraTexPackagesType` and `docType`
2. **Module Options** (lines 70-139): Public API option definitions for both module-level and per-system configuration
3. **Document Processing Logic** (lines 140-280): Complex logic for discovering packages, normalizing configurations, and processing documents
4. **VSCode Integration** (lines 300-430): Comprehensive VSCode settings generation and shell fragment creation
5. **Package Creation** (lines 280-300, 430-480): Logic for creating unified TeX environments, shells, and various derivations
6. **Output Assembly** (lines 480-506): Final flake-parts output configuration

### Problems Identified

1. **Single Responsibility Principle Violation**: The file handles type definitions, business logic, VSCode integration, and output assembly
2. **Testing Complexity**: Testing individual components requires understanding the entire file
3. **Reusability**: VSCode integration and other components could be reused by other modules
4. **Cognitive Load**: 506 lines is too much to hold in working memory
5. **Change Impact**: Modifications to one area (e.g., VSCode settings) require understanding the entire module

## Decision

We will split `modules/latex-utils.nix` into multiple focused modules following these principles:

### Modularization Strategy

1. **Maintain Public API Compatibility**: No breaking changes to user-facing options
2. **Follow flake-parts Patterns**: Each module handles a specific concern while integrating cleanly
3. **Enable Composability**: Components should be reusable and testable independently
4. **Preserve Error Context**: Maintain existing error handling and user experience

### Proposed Module Structure

```
modules/
├── latex-utils.nix           # Main orchestrator module (reduced)
├── latex-utils/
│   ├── types.nix            # Type definitions
│   ├── options.nix          # Option definitions
│   ├── document-processing.nix  # Document discovery and processing logic
│   ├── vscode-integration.nix   # VSCode settings and shell fragments
│   ├── tex-environment.nix     # TeX Live environment creation
│   └── outputs.nix             # Output assembly and derivation creation
└── README.md                # Updated module documentation
```

### Component Responsibilities

#### `latex-utils.nix` (Main Module)

- Import and coordinate all sub-modules
- Maintain backward compatibility
- Minimal orchestration logic
- ~50-80 lines

#### `latex-utils/types.nix`

- `extraTexPackagesType` definition
- `docType` submodule definition
- Type validation helpers
- ~40-60 lines

#### `latex-utils/options.nix`

- All module-level option definitions
- Per-system option definitions using flake-parts-lib
- Option documentation and examples
- ~80-100 lines

#### `latex-utils/document-processing.nix`

- Document discovery and package extraction logic
- Normalization and merging of package configurations
- Error handling for document processing
- ~100-120 lines

#### `latex-utils/vscode-integration.nix`

- VSCode settings generation (`mkVSCodeSettings`)
- Shell fragment creation for VSCode
- ltex-ls wrapper creation
- ~80-100 lines

#### `latex-utils/tex-environment.nix`

- Unified TeX Live environment creation
- Package merging and combination logic
- TeX-related derivation creation
- ~60-80 lines

#### `latex-utils/outputs.nix`

- Final output assembly for flake-parts
- Package, devShell, app, and check creation
- Integration of all components
- ~80-100 lines

## Consequences

### Positive

- **Improved Maintainability**: Each file has a single, clear responsibility
- **Better Testability**: Components can be tested in isolation
- **Enhanced Reusability**: VSCode integration and other components can be reused
- **Easier Navigation**: Developers can quickly find relevant code
- **Reduced Cognitive Load**: Each file is small enough to understand completely
- **Clearer Dependencies**: Import structure makes dependencies explicit

### Negative

- **Increased File Count**: More files to track and maintain
- **Import Complexity**: Need to carefully manage imports and dependencies
- **Potential Circular Dependencies**: Must design interfaces carefully
- **Migration Effort**: Requires careful testing to ensure no regressions

### Neutral

- **No User Impact**: Public API remains identical
- **Testing Requirements**: Existing tests should continue to work unchanged

## Implementation Plan

### Phase 1: Preparation

1. Create comprehensive tests for current behavior to prevent regressions
2. Create the new directory structure (`modules/latex-utils/`)
3. Create README documenting the new structure

### Phase 2: Extract Pure Functions

1. Extract type definitions to `types.nix`
2. Extract option definitions to `options.nix`
3. Update main module to import these

### Phase 3: Extract Business Logic

1. Extract document processing logic to `document-processing.nix`
2. Extract TeX environment creation to `tex-environment.nix`
3. Test integration

### Phase 4: Extract Integration Components

1. Extract VSCode integration to `vscode-integration.nix`
2. Extract output assembly to `outputs.nix`
3. Reduce main module to orchestrator only

### Phase 5: Validation and Documentation

1. Run full test suite to ensure no regressions
2. Update module README with new structure
3. Update architecture documentation if needed

## Risks and Mitigations

### Risk: Breaking Changes During Refactoring

**Mitigation**: Comprehensive test coverage before starting, incremental changes with testing at each step

### Risk: Circular Dependencies Between Modules

**Mitigation**: Careful interface design, using configuration passing patterns rather than direct imports

### Risk: Performance Impact from Multiple Imports

**Mitigation**: Nix's lazy evaluation means unused imports don't impact performance significantly

### Risk: Maintenance Burden of More Files

**Mitigation**: Clear documentation, consistent naming, and logical organization

## Testing Strategy

1. **Regression Testing**: All existing tests must pass after each phase
2. **Component Testing**: New isolated tests for each extracted component
3. **Integration Testing**: Tests that verify correct interaction between components
4. **Documentation Testing**: Ensure examples in options still work

## References

- [Architecture Documentation](../ARCHITECTURE.md)
- [ADR-005: Refined Module API DevShells Fragments](./005-refined-module-api-devshells-fragments.md)
- [ADR-004: Flake-parts Testing Pattern](./004-flake-parts-testing-pattern.md)
