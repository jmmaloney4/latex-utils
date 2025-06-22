# Advanced DevShell Usage: Fragments vs. Complete Shells

## Overview

latex-utils exposes two main ways to get a development shell:

- **Composable fragments:**
  - `config.latex-utils.unifiedTexShell` (unified TeX environment, no VS Code integration)
  - `config.latex-utils.vscodeShell` (TeX environment + VS Code settings integration)
- **Complete shell:** `config.devShells.latex-utils` (ready-to-use shell with VS Code integration enabled by default)

## When to Use Each

- **Use `config.devShells.latex-utils`** if you want a ready-to-go shell for VS Code, with all settings and helpers pre-configured. This is the default and recommended for most users.
- **Use the composable fragments** if you want to compose your own shell, add extra tools, or use a different editor/CI environment.

## Example: Composing with the Fragments

```nix
{
  # Configure documents at module level
  latex-utils.documents = [ /* ... */ ];
  
  perSystem = { config, pkgs, ... }: {
    devShells.myCustom = pkgs.mkShell {
      inputsFrom = [
        config.latex-utils.unifiedTexShell
        config.latex-utils.vscodeShell # Optional: adds VS Code integration
      ];
      buildInputs = [ pkgs.pandoc pkgs.zathura ];
      shellHook = ''
        echo "Custom LaTeX shell with extra tools!"
      '';
    };
  };
}
```

## Enabling/Disabling VS Code Integration

By default, VS Code integration is enabled. To disable it (e.g., for CI or headless use):

```nix
# At module level
latex-utils.enableVSCode = false;
```

When disabled, `config.devShells.latex-utils` will not include VS Code settings or shell hooks.

## Advanced Patterns

- **Multiple shells:** You can provide both a complete VS Code shell and custom shells for different workflows.
- **CI environments:** Use the `unifiedTexShell` fragment for minimal, editor-agnostic shells in CI.
- **Editor-specific tweaks:** Compose the fragments with your own editor integrations.

## Summary Table

| Output                        | Description                                 |
|-------------------------------|---------------------------------------------|
| `config.latex-utils.unifiedTexShell` | Unified TeX environment (composable fragment) |
| `config.latex-utils.vscodeShell`     | TeX environment + VS Code integration (composable fragment) |
| `config.devShells.latex-utils`       | Complete dev shell with VS Code integration |
| `enableVSCode`                | Boolean flag to enable/disable integration  |

See the main README and IDE integration guide for more details. 