# latex-utils
Easily compile latex documents with nix flakes.

Some implementation that can perform similar functions: 
    [tex2nix](https://github.com/rgri/tex2nix), 
    [latex-tools](https://github.com/dexterlb/latex_tools), 
If you are not happy with my implementation, or want to try other similar features, please feel free.

```shell
nix flake init --template github:jackyliu16/latex-utils
```

- [ ] provide more information and a help panel for easily debug
- [ ] provide support of multiple compilations like xelatex -> bibtex -> xelatex -> xelatex
- [x] Fixed identification of RequirePackage
- [ ] Due to regular expression limitations, cross-line RequirePackage and usepackage cannot now be detected, need to manually convert it into one line .
      
```tex
\RequirePackage[
a4paper,
left=3cm,right=2.3cm,top=2.3cm,bottom=2.6cm,
headheight=10cm,
headsep=0.3cm]{geometry}
```

- [ ] Right now, there is inputFile required, if the default operation doesn't belong to latex_utils, it seems reasonless to provide this kind of variable, never mention the chance may use it right here (overlays buildPhase and installPhase in flakes).
