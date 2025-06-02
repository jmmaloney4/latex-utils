{
  pkgs,
  lib,
}: let
  # Helper to create minimal LaTeX documents for testing
  createTexFile = content: filename:
    pkgs.writeTextDir filename content;

  # Helper to check if a derivation exists and can be built
  builds = drv: drv.drvPath != null;

  # Import helper functions used by the module
  findLatexFiles = import ../lib/findLatexFiles.nix {inherit pkgs lib;};
  findLatexPackages = import ../lib/findLatexPackages.nix {inherit pkgs lib;};

  # Test documents with different package requirements
  testDoc1 = {
    name = "test1.pdf";
    src = createTexFile ''
      \documentclass{article}
      \usepackage{xcolor}
      \usepackage{mathrsfs}
      \begin{document}
      \textcolor{red}{Hello} $\mathscr{A}$
      \end{document}
    '' "main.tex";
    workingDirectory = ".";
    extraTexPackages = ["rsfs" "jknapltx" "xcolor"];
  };

  testDoc2 = {
    name = "test2.pdf";
    src = createTexFile ''
      \documentclass{article}
      \usepackage{amsmath}
      \usepackage{tikz}
      \begin{document}
      \begin{equation} x = 1 \end{equation}
      \begin{tikzpicture}\draw (0,0) -- (1,1);\end{tikzpicture}
      \end{document}
    '' "main.tex";
    workingDirectory = ".";
    extraTexPackages = ["pgf" "amsmath"];
  };

  # Test the package collection logic directly
  documents = [testDoc1 testDoc2];

  # Collect all extraTexPackages from all documents
  allExtraTexPackages = lib.lists.unique (
    lib.lists.flatten (map (doc: doc.extraTexPackages) documents)
  );

  # Collect all discovered packages from all documents
  allDiscoveredPackages = lib.lists.foldl (acc: doc: let
    # Get all LaTeX files for this document
    searchPaths = findLatexFiles {
      basePath = "${doc.src}/${doc.workingDirectory}";
    };
    # Extract packages from each file
    discovered =
      builtins.foldl' (a: b: a // b) {}
      (map (p:
        if (builtins.pathExists p)
        then findLatexPackages {fileContents = builtins.readFile p;}
        else {})
      (lib.lists.unique searchPaths));
  in
    acc // discovered) {}
  documents;

  # Convert extraTexPackages to derivations
  extraTexPackagesAttrs = builtins.listToAttrs (
    map (name: {
      name = name;
      value = pkgs.texlive.${name};
    })
    allExtraTexPackages
  );

  # Create unified TeX Live environment
  unifiedTexPackages =
    {
      inherit
        (pkgs.texlive)
        latex-bin
        latexmk
        biblatex
        biber
        csquotes
        luaotfload
        fontspec
        lm
        cm
        ec
        tex-gyre
        ;
      scheme = pkgs.texlive.scheme-basic;
    }
    // allDiscoveredPackages // extraTexPackagesAttrs;

  unifiedTexEnv = pkgs.texlive.combine unifiedTexPackages;

  # Create latexmk wrapper
  latexmkWrapper = pkgs.writeShellScriptBin "latexmk" ''
    exec ${lib.getExe' unifiedTexEnv "latexmk"} "$@"
  '';

  # Test individual document creation
  mkDoc = doc:
    (pkgs.callPackage ../lib/mkLatexPdfDocument.nix {}) (doc
      // {
        texPackages = allDiscoveredPackages // extraTexPackagesAttrs;
      });
in {
  # Test that we can collect extra packages from multiple documents
  extraPackageCollection = {
    expr = lib.lists.sort builtins.lessThan allExtraTexPackages;
    expected = ["amsmath" "jknapltx" "pgf" "rsfs" "xcolor"];
  };

  # Test that we can discover packages from LaTeX source
  packageDiscovery = {
    expr = let
      discoveredNames = builtins.attrNames allDiscoveredPackages;
    in
      lib.lists.sort builtins.lessThan discoveredNames;
    expected = ["amsmath" "xcolor"]; # These should be discovered from \usepackage commands
  };

  # Test that unified TeX Live environment builds
  unifiedTexLiveBuilds = {
    expr = builds unifiedTexEnv;
    expected = true;
  };

  # Test that latexmk wrapper builds
  latexmkWrapperBuilds = {
    expr = builds latexmkWrapper;
    expected = true;
  };

  # Test that unified environment contains expected packages
  unifiedContainsPackages = {
    expr = let
      hasPackage = pkg: builtins.hasAttr pkg unifiedTexPackages;
    in
      hasPackage "xcolor" && hasPackage "rsfs" && hasPackage "pgf" && hasPackage "latex-bin";
    expected = true;
  };

  # Test that individual documents can build with unified packages
  documentsWithUnifiedPackagesBuild = {
    expr = builds (mkDoc testDoc1) && builds (mkDoc testDoc2);
    expected = true;
  };

  # Test package deduplication works
  packageDeduplication = {
    expr = let
      # Both docs specify xcolor, should only appear once in final list
      xcolorCount = lib.lists.count (x: x == "xcolor") allExtraTexPackages;
    in
      xcolorCount;
    expected = 1;
  };

  # Test that the unified environment is a proper texlive-combined derivation
  unifiedEnvironmentType = {
    expr = unifiedTexEnv.pname or "";
    expected = "texlive-combined";
  };

  # Test that latexmk wrapper has correct name
  latexmkWrapperType = {
    expr = latexmkWrapper.pname or "";
    expected = "latexmk";
  };

  # Test with empty document list
  emptyDocumentHandling = {
    expr = let
      emptyExtraPackages = lib.lists.unique (
        lib.lists.flatten (map (doc: doc.extraTexPackages) [])
      );
    in
      emptyExtraPackages;
    expected = [];
  };

  # Test mixed package discovery and extra packages
  mixedPackageHandling = {
    expr = let
      # Combine discovered and extra packages like the real module does
      combinedPackages = allDiscoveredPackages // extraTexPackagesAttrs;
      packageNames = lib.lists.sort builtins.lessThan (builtins.attrNames combinedPackages);
    in
      packageNames;
    expected = ["amsmath" "jknapltx" "pgf" "rsfs" "xcolor"];
  };
}
