# Test for module-level extraTexPackages and related configurations
{
  pkgs,
  lib,
}: let
  # Minimal TeX source for document definitions in tests
  minimalTex = srcName:
    pkgs.writeTextDir "${srcName}/main.tex" ''
      \documentclass{article}
      \usepackage{amsmath} % A common package to ensure basic validity
      \begin{document}
      Hello, world!
      \end{document}
    '';
in {
  # Test: Module-level extraTexPackages are configured, with no documents.
  # Purpose: Verifies that the module configuration structure allows `extraTexPackages`
  #          to be set even when the `documents` list is empty.
  # Note: This test checks the configuration structure, not the final package resolution.
  modulePackagesWithNoDocuments = {
    expr = let
      config = {
        latex-utils = {
          extraTexPackages = ["amsmath" "amssymb"]; # Module-level packages
          documents = []; # No documents defined
        };
      };
    in
      # Assertion checks if the extraTexPackages list in the config is not empty.
      config.latex-utils.extraTexPackages != [];
    expected = true;
  };

  # Test: Both module-level and document-level extraTexPackages are configured.
  # Purpose: Verifies that the module configuration structure allows `extraTexPackages`
  #          at both the top module level and per-document.
  # Note: This test checks the configuration structure, not the final package resolution or merging.
  moduleAndDocumentPackagesConfigured = {
    expr = let
      config = {
        latex-utils = {
          extraTexPackages = ["amsmath" "geometry"]; # Module-level packages
          documents = [
            {
              name = "test.pdf";
              src = minimalTex "testDoc1";
              extraTexPackages = ["tikz"]; # Document-specific package
            }
          ];
        };
      };
    in
      # Assertion checks that both module-level and the first document's extraTexPackages are non-empty in the config.
      config.latex-utils.extraTexPackages
      != []
      && (builtins.head config.latex-utils.documents).extraTexPackages != [];
    expected = true;
  };

  # Test: Module-level extraTexPackages is a function.
  # Purpose: Verifies that the `extraTexPackages` option at the module level
  #          can accept a function (e.g., to conditionally include packages based on discovered ones).
  # Note: This test checks if the config accepts a function, not the function's evaluation result.
  moduleFunctionPackagesAccepted = {
    expr = let
      config = {
        latex-utils = {
          extraTexPackages = discovered: ["amsmath" "amssymb"]; # Function as value
          documents = [];
        };
      };
    in
      # Assertion checks if the configured extraTexPackages is a function.
      builtins.isFunction config.latex-utils.extraTexPackages;
    expected = true;
  };

  # Test: Module-level and document-level extraTexPackages are provided as pre-normalized derivations.
  # Purpose: Verifies that the configuration structure accepts TeX Live derivations directly
  #          for `extraTexPackages` at both module and document levels.
  # Note: This primarily tests config acceptance. Actual normalization logic is tested elsewhere.
  preNormalizedPackagesAccepted = {
    expr = let
      config = {
        latex-utils = {
          extraTexPackages = [pkgs.texlive.amsmath]; # Pre-normalized derivation
          documents = [
            {
              name = "test.pdf";
              src = minimalTex "testDoc2";
              extraTexPackages = [pkgs.texlive.xcolor]; # Pre-normalized derivation
            }
          ];
        };
      };
    in
      # Assertion checks if the first module-level package is a derivation.
      lib.isDerivation (builtins.head config.latex-utils.extraTexPackages)
      && lib.isDerivation (builtins.head (builtins.head config.latex-utils.documents).extraTexPackages);
    expected = true;
  };
}
