{
  pkgs,
  lib,
}: let
  # Helper to build a document with mkLatexPdfDocument
  mkDoc = args: pkgs.callPackage ../lib/mkLatexPdfDocument.nix {} args;
  # Minimal .tex file contents for testing
  minimalTex = srcName: packageLines:
    pkgs.writeTextDir "${srcName}/main.tex" ''
      \documentclass{article}
      ${packageLines}
      \begin{document}
      Hello, world!
      \end{document}
    '';
  # Helper to check if a derivation builds
  builds = drv: drv.drvPath != null;

  # Resolve potentially problematic packages at the top level
  resolvedAmstex = pkgs.texlive.amsfonts;
  resolvedAmsrefs = pkgs.texlive.amsrefs;
in {
  directDerivationCheck = {
    expr = let
      isAmstexDrv = lib.isDerivation resolvedAmstex;
      isAmsrefsDrv = lib.isDerivation resolvedAmsrefs;
      _traceAmstexType = builtins.trace "TRACE resolvedAmstex.type: ${toString (resolvedAmstex.type or "TYPE_ATTR_MISSING")}" true;
      _traceAmsrefsType = builtins.trace "TRACE resolvedAmsrefs.type: ${toString (resolvedAmsrefs.type or "TYPE_ATTR_MISSING")}" true;
      _traceAmstexIsDrv = builtins.trace "TRACE isAmstexDrv: ${toString isAmstexDrv}" true;
      _traceAmsrefsIsDrv = builtins.trace "TRACE isAmsrefsDrv: ${toString isAmsrefsDrv}" true;
    in
      isAmstexDrv && isAmsrefsDrv;
    expected = true;
  };

  singleExtra = {
    expr = builds (mkDoc {
      name = "test.pdf";
      src = minimalTex "singleExtra" "\\usepackage{xcolor}";
      extraTexPackages = ["xcolor"];
    });
    expected = true;
  };

  multipleExtras = {
    expr = builds (mkDoc {
      name = "test.pdf";
      src = minimalTex "multipleExtras" "\\usepackage{mathrsfs} % CTAN: rsfs\n\\usepackage{xcolor}";
      extraTexPackages = ["rsfs" "xcolor"];
    });
    expected = true;
  };

  noExtras = {
    expr = builds (mkDoc {
      name = "test.pdf";
      src = minimalTex "noExtras" "";
    });
    expected = true;
  };

  emptyList = {
    expr = builds (mkDoc {
      name = "test.pdf";
      src = minimalTex "emptyList" "";
      extraTexPackages = [];
    });
    expected = true;
  };

  overrideDiscovered = {
    expr = builds (mkDoc {
      name = "test.pdf";
      src = minimalTex "overrideDiscovered" "\\usepackage{xcolor}";
      extraTexPackages = ["xcolor"];
    });
    expected = true;
  };

  multipleDocs = {
    expr = let
      doc1 = mkDoc {
        name = "doc1.pdf";
        src = minimalTex "doc1" "\\usepackage{xcolor}";
        extraTexPackages = ["xcolor"];
      };
      doc2 = mkDoc {
        name = "doc2.pdf";
        src = minimalTex "doc2" "\\usepackage{mathrsfs} % CTAN: rsfs";
        extraTexPackages = ["rsfs"];
      };
    in
      builds doc1 && builds doc2;
    expected = true;
  };

  alreadyInScheme = {
    expr = builds (mkDoc {
      name = "test.pdf";
      src = minimalTex "alreadyInScheme" "";
      extraTexPackages = ["lm"]; # lm is in scheme-basic
    });
    expected = true;
  };

  integration = {
    expr = builds (mkDoc {
      name = "test.pdf";
      src = minimalTex "integration" "\\usepackage{xcolor}";
      inputFile = "main.tex";
      outputPath = "output.pdf";
      extraTexPackages = ["xcolor"];
    });
    expected = true;
  };

  # Test new functionality: List of derivations
  listOfDerivations = {
    expr = builds (mkDoc {
      name = "test.pdf";
      src = minimalTex "listOfDerivations" "\\usepackage{xcolor}\\usepackage{mathrsfs} % CTAN: rsfs"; # rsfs is mathrsfs
      extraTexPackages = [pkgs.texlive.xcolor pkgs.texlive.rsfs]; # Use derivations
    });
    expected = true;
  };

  # Test new functionality: Function returning derivations
  functionReturningDerivations = {
    expr = builds (mkDoc {
      name = "test.pdf";
      src = minimalTex "functionReturningDerivations" "\\usepackage{amsmath}";
      extraTexPackages = discovered:
        if builtins.hasAttr "amsmath" discovered
        then let
          # Trace the raw values from top-level
          _tracedFontRaw = builtins.trace "TRACE resolvedAmstex (in function): ${builtins.toString resolvedAmstex}" resolvedAmstex;
          _tracedRefsRaw = builtins.trace "TRACE resolvedAmsrefs (in function): ${builtins.toString resolvedAmsrefs}" resolvedAmsrefs;

          # Assert drvPath presence and access it
          # This will fail if resolvedAmstex/Refs are not derivations or don't have drvPath
          fontDrvPath = assert (resolvedAmstex ? drvPath); resolvedAmstex.drvPath;
          refsDrvPath = assert (resolvedAmsrefs ? drvPath); resolvedAmsrefs.drvPath;

          # Use the packages after asserting drvPath. The primary purpose of the above is to see if it errors.
          fontPkg = resolvedAmstex;
          refsPkg = resolvedAmsrefs;

          _finalTrace = builtins.trace "TRACE fontPkg (in function after .drvPath access): ${builtins.toString fontPkg}, refsPkg: ${builtins.toString refsPkg}" true;
        in [fontPkg refsPkg]
        else [];
    });
    expected = true;
  };

  # # Test new functionality: Function with conditional logic
  # functionConditional = {
  #   expr = builds (mkDoc {
  #     name = "test.pdf";
  #     src = minimalTex "functionConditional" "\\usepackage{geometry}";
  #     extraTexPackages = discovered:
  #       if builtins.hasAttr "geometry" discovered
  #       then ["fancyhdr" "lastpage"]
  #       else ["geometry"];
  #   });
  #   expected = true;
  # };

  # # Test backward compatibility: empty function
  # emptyFunction = {
  #   expr = builds (mkDoc {
  #     name = "test.pdf";
  #     src = minimalTex "emptyFunction" "";
  #     extraTexPackages = discovered: [];
  #   });
  #   expected = true;
  # };
}
