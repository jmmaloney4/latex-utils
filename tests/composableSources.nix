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

  sharedTemplateSrc = pkgs.writeTextDir "cavinslegal.cls" ''
    \NeedsTeXFormat{LaTeX2e}
    \ProvidesClass{cavinslegal}[2026/09/12 Shared legal class]
    \LoadClass{article}
    \usepackage{xcolor}
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

  additionalSourcesDoc = builtins.head additionalSourcesProcessing.processedDocuments;
  additionalSourcesDrv = additionalSourcesProcessing.mkDoc docWithAdditionalSources;
  commonSourcesDoc = builtins.head commonSourcesProcessing.processedDocuments;
  commonSourcesDrv = commonSourcesProcessing.mkDoc docWithCommonSources;
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
      lib.isDerivation additionalSourcesDrv.src
      && lib.hasInfix "agreement.pdf-latex-sources" additionalSourcesDrv.src.name
      && lib.hasInfix "$out/generated/jack-maloney/" additionalSourcesDrv.src.buildCommand
      && lib.hasInfix "${sharedTemplateSrc}/." additionalSourcesDrv.src.buildCommand;
    expected = true;
  };

  testCommonAdditionalSourcesComposeDocumentSrc = {
    expr =
      lib.isDerivation commonSourcesDrv.src
      && lib.hasInfix "common-agreement.pdf-latex-sources" commonSourcesDrv.src.name
      && lib.hasInfix "$out/generated/jack-maloney/" commonSourcesDrv.src.buildCommand
      && lib.hasInfix "${sharedTemplateSrc}/." commonSourcesDrv.src.buildCommand;
    expected = true;
  };
}
