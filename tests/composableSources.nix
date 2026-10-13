{
  pkgs,
  lib,
  ...
}: let
  moduleDocSrc = pkgs.writeTextDir "generated/jack-maloney/main.tex" ''
    \documentclass{cavinslegal}
    \begin{document}
    Shared template document
    \end{document}
  '';

  sharedTemplateSrc = pkgs.writeTextDir "templates/cavinslegal.cls" ''
    \NeedsTeXFormat{LaTeX2e}
    \ProvidesClass{cavinslegal}[2026/09/12 Shared legal class]
    \LoadClass{article}
    \usepackage{xcolor}
  '';

  documentOverrideSrc = pkgs.writeTextDir "overrides/cavinslegal.cls" ''
    \NeedsTeXFormat{LaTeX2e}
    \ProvidesClass{cavinslegal}[2026/09/12 Document override class]
    \LoadClass{article}
  '';

  mkProcessing = {
    documents,
    moduleCommonAdditionalSources ? [],
  }:
    import ../modules/latex-utils/document-processing.nix {
      inherit pkgs lib documents moduleCommonAdditionalSources;
      moduleExtraTexPackages = [];
    };

  docWithAdditionalSources = {
    name = "agreement.pdf";
    src = moduleDocSrc;
    workingDirectory = "generated/jack-maloney";
    inputFile = "main.tex";
    additionalSources = [sharedTemplateSrc];
  };

  docWithCommonSources = {
    name = "common-agreement.pdf";
    src = moduleDocSrc;
    workingDirectory = "generated/jack-maloney";
    inputFile = "main.tex";
  };

  additionalSourcesProcessing = mkProcessing {
    documents = [docWithAdditionalSources];
  };

  commonSourcesProcessing = mkProcessing {
    documents = [docWithCommonSources];
    moduleCommonAdditionalSources = [sharedTemplateSrc];
  };

  precedenceProcessing = mkProcessing {
    documents = [
      (docWithAdditionalSources
        // {
          additionalSources = [documentOverrideSrc];
        })
    ];
    moduleCommonAdditionalSources = [sharedTemplateSrc];
  };

  additionalSourcesDoc = builtins.head additionalSourcesProcessing.processedDocuments;
  additionalSourcesDrv = additionalSourcesProcessing.mkDoc docWithAdditionalSources;
  commonSourcesDoc = builtins.head commonSourcesProcessing.processedDocuments;
  commonSourcesDrv = commonSourcesProcessing.mkDoc docWithCommonSources;
  precedenceDrv = precedenceProcessing.mkDoc (
    docWithAdditionalSources
    // {
      additionalSources = [documentOverrideSrc];
    }
  );
in {
  testAdditionalSourcesAreScannedForPackages = {
    expr = additionalSourcesDoc.discovered ? xcolor;
    expected = true;
  };

  testCommonAdditionalSourcesAreScannedForPackages = {
    expr = commonSourcesDoc.discovered ? xcolor;
    expected = true;
  };

  testAdditionalSourcesComposeDocumentSrc = {
    expr =
      lib.hasInfix "TEXINPUTS" additionalSourcesDrv.buildPhase
      && lib.hasInfix "${sharedTemplateSrc}" additionalSourcesDrv.buildPhase;
    expected = true;
  };

  testCommonAdditionalSourcesComposeDocumentSrc = {
    expr =
      lib.hasInfix "TEXINPUTS" commonSourcesDrv.buildPhase
      && lib.hasInfix "${sharedTemplateSrc}" commonSourcesDrv.buildPhase;
    expected = true;
  };

  testDocumentAdditionalSourcesPrecedeCommonSources = {
    expr = let
      buildPhaseParts = lib.splitString "${documentOverrideSrc}" precedenceDrv.buildPhase;
    in
      builtins.length buildPhaseParts > 1
      && lib.hasInfix "${sharedTemplateSrc}" (builtins.elemAt buildPhaseParts 1);
    expected = true;
  };
}
