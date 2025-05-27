# latex-utils
Easily compile latex documents with nix flakes.

## Usage with flake-parts

Add this flake as an input and import the module in your flake-parts-based flake:

```nix
# flake.nix in your LaTeX project
{
  inputs.latex-utils.url = "github:jmmaloney4/latex-utils";
  inputs.flake-parts.url = "github:hercules-ci/flake-parts";

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];
      imports = [ inputs.latex-utils.modules.latex-utils ];
      # Enable the module
      latex-utils.enable = true;
      perSystem = { pkgs, ... }: {
        packages.myDoc = config.mkLatexPdfDocument {
          name = "mydoc";
          src = ./.;
        };
      };
    };
}
```

```shell
nix flake init --template github:jmmaloney4/latex-utils
```
