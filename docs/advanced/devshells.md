# Advanced DevShell Usage: Fragments vs. Turn-Key Shells

## Overview

latex-utils exposes two main ways to get a development shell:

- **Composable fragments:**
  - `config.latex-utils.build.unifiedTexShell` (unified TeX, no VS Code integration)
  - `config.latex-utils.build.vscodeSettingsShell` (links VS Code settings.json)
- **Turn-key shell:** `config.latex-utils.devShells.full` (includes VS Code integration if enabled)

## When to Use Each

- **Use `devShells.full`** if you want a ready-to-go shell for VS Code, with all settings and helpers pre-configured. This is the default and recommended for most users.
- **Use the composable fragments** if you want to compose your own shell, add extra tools, or use a different editor/CI environment.

## Example: Composing with the Fragments

```nix
perSystem = { config, pkgs, ... }: {
  devShells.myCustom = pkgs.mkShell {
    inputsFrom = [
      config.latex-utils.build.unifiedTexShell
      config.latex-utils.build.vscodeSettingsShell # Optional: links VS Code settings
    ];
    buildInputs = [ pkgs.pandoc pkgs.zathura ];
    shellHook = ''
      echo "Custom LaTeX shell with extra tools!"
    '';
  };
};
```

## Enabling/Disabling VS Code Integration

By default, VS Code integration is enabled. To disable it (e.g., for CI or headless use):

```nix
latex-utils.enableVSCode = false;
```

When disabled, `devShells.full` will not include VS Code settings or shell hooks.

## Advanced Patterns

- **Multiple shells:** You can provide both a full VS Code shell and custom shells for different workflows.
- **CI environments:** Use the fragment for minimal, editor-agnostic shells in CI.
- **Editor-specific tweaks:** Compose the fragment with your own editor integrations.

## Summary Table

| Output                        | Description                                 |
|-------------------------------|---------------------------------------------|
| `build.devShell`              | Composable fragment, no VS Code integration |
| `devShells.full`              | Turn-key shell, VS Code integration         |
| `enableVSCode`                | Boolean flag to enable/disable integration  |

See the main README and IDE integration guide for more details. 