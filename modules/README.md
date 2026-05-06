# LaTeX Utils Modules

This directory contains the modularized components of the latex-utils flake-parts module.

## Structure

- **`latex-utils.nix`** - Main orchestrator module that imports and coordinates all sub-modules
- **`latex-utils/`** - Directory containing focused component modules:
  - **`types.nix`** - Type definitions (`extraTexPackagesType`, `docType`)
  - **`options.nix`** - Module option definitions and documentation
  - **`document-processing.nix`** - Document discovery and package processing logic
  - **`vscode-integration.nix`** - VSCode settings generation and shell fragments
  - **`tex-environment.nix`** - TeX Live environment creation and management
  - **`outputs.nix`** - Final output assembly for flake-parts

## Design Principles

1. **Single Responsibility**: Each module handles one specific concern
2. **Composability**: Components can be tested and reused independently
3. **API Preservation**: Public API remains unchanged for backward compatibility
4. **Clear Dependencies**: Import structure makes dependencies explicit

## Usage

The main `latex-utils.nix` module imports all components and provides the same public API as before:

```nix
{
  imports = [
    inputs.latex-utils.flakeModules.default
  ];
  
  latex-utils = {
    documents = [
      {
        name = "my-paper.pdf";
        src = ./src;
        extraTexPackages = ["amsmath" "tikz"];
      }
    ];
    enableVSCode = true;
  };
}
```

## Testing

Each component can be tested independently, and the full integration is validated through the existing test suite in `tests/`.

## Migration Notes

This modularization was implemented following [ADR-008: Modularize Large latex-utils.nix Module](../docs/internal/decisions/008-modularize-latex-utils-module.md).

The refactoring maintains 100% backward compatibility - no user configuration changes are required.
