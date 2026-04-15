# ADR 012: Emoji Support via LuaLaTeX
*Date:* 2026-01-08
*Status:* proposed

## Context
Users want emoji support in documents built with latex-utils. Current builds are
Nix-sandboxed and rely on a prebuilt fontconfig cache derived from the TeX
environment. This has a few constraints:
- pdfLaTeX does not support Unicode emoji or color emoji fonts.
- XeLaTeX can render some monochrome emoji but does not reliably handle modern
  color emoji fonts.
- Color emoji require OpenType color fonts and shaping support (HarfBuzz), which
  is only dependable with LuaHBTeX (LuaLaTeX in TeX Live).
- System fonts are not visible inside Nix builds; fonts must be supplied
  explicitly to the fontconfig cache for reproducible output.

## Decision
Adopt a LuaLaTeX-first solution that integrates the `emoji` package and makes
emoji fonts available through a configurable font list:
- Keep `lualatex` as the recommended engine for emoji rendering.
- Document usage of the `emoji` package (and `\setemojifont{...}`) for authors.
- Add a new option to supply external font derivations (e.g., `noto-fonts-emoji`)
  so the fontconfig cache includes emoji fonts during builds and in dev shells.
- Merge module-level and document-level font lists, mirroring existing
  `extraTexPackages` behavior for consistency.

## Alternatives Considered
1. **XeLaTeX only** - supports limited monochrome emoji; unreliable for color
   emoji fonts in TeX Live.
2. **pdfLaTeX with image substitution** - works but requires manual image
   management and loses text semantics.
3. **LuaLaTeX with explicit emoji fonts (chosen)** - aligns with current default
   engine and provides the best color emoji support in TeX Live.

## Consequences
- **Pros:**
  - Reproducible emoji rendering in Nix builds.
  - Matches the project default engine and avoids per-doc engine switches.
  - Flexible font selection per project or document.
- **Cons:**
  - Requires LuaLaTeX and a compatible color emoji font.
  - Adds additional build inputs (font packages) and cache cost.

## Technical Details
- New options (names TBD):
  - `latex-utils.extraFonts` (module-level list of font derivations)
  - `latex-utils.documents[].extraFonts` (optional per-document list)
- Update `lib/mkLatexPdfDocument.nix` to pass `[texEnv] ++ extraFonts` to
  `lib/mkFontconfigCache.nix`.
- Update `modules/latex-utils/document-processing.nix` to merge module-level
  and document-level font lists similarly to `extraTexPackages`.
- Update `modules/latex-utils/tex-environment.nix` to include extra font
  derivations in dev shells and set `FONTCONFIG_FILE`/`FONTCONFIG_CACHE_DIR`
  to the prebuilt cache for consistent font discovery.

## Appendices

### Appendix A: Example LaTeX usage
```tex
\usepackage{emoji}
\setemojifont{Noto Color Emoji}
Hello \emoji{rocket} \emoji{sparkles}
```

### Appendix B: Example Nix configuration
```nix
latex-utils.extraTexPackages = [ "emoji" ];
latex-utils.extraFonts = [ pkgs.noto-fonts-emoji ];
latex-utils.latexmk.engine = "lualatex";
```
