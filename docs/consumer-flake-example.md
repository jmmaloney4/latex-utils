# Consumer Flake Simplification Example

## Before: Complex Manual Setup

```nix
{
  # ... inputs ...
  
  outputs = { latex-utils, ... } @ inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.latex-utils.modules.latex-utils ];
      
      latex-utils.documents = [
        {
          name = "eqi-notes.pdf";
          src = ./.;
          inputFile = "main.tex";
          extraTexPackages = [ "enumitem" "metafont" "mfware" ];
        }
        # ... more documents with map logic ...
      ];

      perSystem = { config, self', pkgs, lib, ... }: 
      let
        # Manual path configuration
        latexmkPath = "${pkgs.texlive.combined.scheme-full}/bin/latexmk";
        ltexlsPath = "${pkgs.ltex-ls}/bin/ltex-ls";

        # Custom VSCode settings generation
        vscodeSettingsJson = import ./nix/vscode-settings.nix {
          inherit latexmkPath ltexlsPath;
        };
      in {
        # Manual VSCode settings package
        packages.vscode-settings = pkgs.writeTextFile {
          name = "vscode-settings";
          destination = "/.vscode/settings.json";
          text = vscodeSettingsJson;
        };

        devShells.default = pkgs.mkShell {
          inputsFrom = [
            config.mission-control.devShell
            config.pre-commit.devShell
            config.treefmt.build.devShell
          ] ++ builtins.map (x: self'.packages.${x}) (builtins.attrNames self'.packages);
          
          buildInputs = with pkgs; [
            ltex-ls
            (texlive.combine {
              inherit (texlive) scheme-medium enumitem tikz-cd;
            })
          ];
          
          # Manual VSCode setup
          shellHook = ''
            echo "🔧 Updating VSCode settings symlink..."
            mkdir -p .vscode
            ln -sf "${self'.packages.vscode-settings}/.vscode/settings.json" .vscode/settings.json
            echo "✅ VSCode settings linked successfully!"
          '';
        };
        
        # ... rest of config ...
      };
    };
}
```

## After: Simplified with latex-utils VSCode Integration

```nix
{
  # ... inputs ...
  
  outputs = { latex-utils, ... } @ inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.latex-utils.modules.latex-utils ];
      
      latex-utils.documents = [
        {
          name = "eqi-notes.pdf";
          src = ./.;
          inputFile = "main.tex";
          extraTexPackages = [ "enumitem" "metafont" "mfware" ];
        }
        # ... more documents with map logic ...
      ];

      perSystem = { config, self', pkgs, ... }: {
        devShells.default = pkgs.mkShell {
          inputsFrom = [
            config.mission-control.devShell
            config.pre-commit.devShell
            config.treefmt.build.devShell
            self'.devShells.vscode  # 🎉 One line replaces all the manual setup!
          ];
          
          # No manual TeX Live setup needed - comes from VSCode devshell
          # No manual VSCode settings - automatically generated and linked
          # No path configuration needed - uses unified environment
        };
        
        # ... rest of config ...
      };
    };
}
```

## Key Improvements

### ✅ **Eliminated Manual Configuration**
- ❌ No more manual `latexmkPath` and `ltexlsPath` configuration
- ❌ No more custom VSCode settings generation
- ❌ No more manual symlink setup in shellHook
- ❌ No more separate TeX Live environment configuration

### ✅ **Automatic Benefits**
- ✅ **Unified TeX Live**: Uses unified environment with all document packages
- ✅ **VSCode Integration**: Pre-configured LaTeX Workshop settings
- ✅ **LTeX-LS**: Automatic spell/grammar checking setup
- ✅ **Package Management**: All required packages automatically included

### ✅ **Simplified Maintenance**
- ✅ **Single Source of Truth**: All TeX packages defined in `latex-utils.documents`
- ✅ **Automatic Updates**: VSCode settings automatically use correct paths
- ✅ **Less Code**: Significantly reduced boilerplate

## Custom VSCode Settings (Optional)

If you need custom VSCode settings, you can still override them:

```nix
perSystem = { self', pkgs, ... }: {
  packages.my-vscode-settings = self'.packages.vscode-settings-with-overrides {
    "ltex.language" = "en-GB";  # Your preferred language
    "latex-workshop.latex.autoBuild.run" = "never";  # Custom build behavior
  };
  
  devShells.default = pkgs.mkShell {
    inputsFrom = [
      # your other shells
    ];
    buildInputs = [
      self'.packages.texlive-unified  # Still get the unified environment
    ];
    shellHook = ''
      mkdir -p .vscode
      ln -sf "${self'.packages.my-vscode-settings}/.vscode/settings.json" .vscode/settings.json
    '';
  };
};
```

## Migration Steps

1. **Remove manual configuration**:
   - Delete custom `vscode-settings.nix` file
   - Remove manual path variables (`latexmkPath`, `ltexlsPath`)
   - Remove custom VSCode settings package

2. **Update devShell**:
   - Add `self'.devShells.vscode` to `inputsFrom`
   - Remove manual TeX Live packages from `buildInputs`
   - Remove VSCode setup from `shellHook`

3. **Enjoy the simplicity**! 🎉

The unified TeX Live environment automatically includes all packages from all your documents, and VSCode is pre-configured to use it. 