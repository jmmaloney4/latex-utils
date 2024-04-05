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
- [x] provide support of multiple compilations like xelatex -> bibtex -> xelatex -> xelatex
    Right now we could finish this job with override buildPhase like `xelatex main.tex; bibtex main.aux; xelatex main.tex`,
    should we provide latexmk as default ? it look fine for me to replace this kind of operation.
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
- [ ] Maybe we should base on [latexmk](https://zhuanlan.zhihu.com/p/256370737), [latex-tools](https://github.com/dexterlb/latex_tools) impl watch operation,
      should we just simpliy abstract the document, and provide diff kinds of package of build or watch or just make up this kind of operation in devShells.
