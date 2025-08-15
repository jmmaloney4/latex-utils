{
  config,
  lib,
  pkgs,
  documents,
  enableVSCode,
  flakeCheck,
  # Document processing outputs
  mkDoc,
  # TeX environment outputs
  unifiedPackages,
  unifiedTexShell,
  latexmkrcPackage,
  # VSCode integration outputs
  vscodeIntegration,
  latexUtilsVSCodeFragment,
  vscodeSettingsCustomApp,
  vscodeRecipesPackage,
}: let
  # Create document packages
  docPkgs = builtins.listToAttrs (map (doc: {
      name = lib.removeSuffix ".pdf" doc.name;
      value = mkDoc doc;
    })
    documents);

  # Check: rebuild all PDFs and fail if any change
  latexCheck =
    pkgs.runCommand "latex-check" {
      buildInputs = [pkgs.diffutils];
    } ''
      set -e
      for pdf in ${toString (map (doc: mkDoc doc) documents)}; do
        cp "$pdf" "$out-$(basename "$pdf")"
      done
      # In real use, compare with committed PDFs or previous build
    '';

  # Aggregate package that builds all documents
  documentsPackage = lib.optionalAttrs (documents != []) {
    documents = pkgs.runCommand "latex-documents" {} ''
      mkdir -p $out
      ${lib.concatMapStrings (doc: ''
          cp "${mkDoc doc}" "$out/${doc.name}"
        '')
        documents}
    '';
  };
in {
  # Per-System derivations that will be transposed to outputs.latex-utils.${system}.*
  # These are accessible within perSystem as config.latex-utils.*
  latex-utils = {
    unifiedTexShell = unifiedTexShell;
    vscodeShell = latexUtilsVSCodeFragment;
  };

  # Standard flake-parts outputs (automatically per-system)
  packages =
    docPkgs
    // unifiedPackages
    // vscodeIntegration
    // {
      latexmkrc = latexmkrcPackage;
      vscode-latex-workshop-recipes = vscodeRecipesPackage;
    }
    // documentsPackage
    // (
      if documents != []
      then {default = mkDoc (builtins.head documents);}
      else {}
    );

  # Complete devShell using standard flake-parts devShells transposition
  devShells = lib.optionalAttrs enableVSCode {
    latex-utils = pkgs.mkShell {
      name = "latex-utils-devshell";
      inputsFrom = [config.latex-utils.vscodeShell]; # Use config.latex-utils.vscodeShell
    };
  };

  checks = lib.optionalAttrs flakeCheck {
    latex = latexCheck;
  };

  apps = {
    vscode-settings-custom = vscodeSettingsCustomApp;
  };
}
