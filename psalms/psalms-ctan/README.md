# Psalms — Latin Psalm Typesetting

This bundle provides LuaLaTeX support for typesetting Latin psalms with
Gregorian psalm tones.  It ships with UTF-8 psalm texts, a Lua helper module
that performs syllabification and accent placement, and a LaTeX package that
exposes a single `\psalm` command.

## Contents

- `tex/latex/psalms/psalms.sty` — package interface
- `tex/latex/psalms/psalms/` — psalm and canticle source texts (UTF-8)
- `tex/lualatex/psalms/psalmtones.lua` — tone presets and syllable logic
- `doc/latex/psalms/psalms-doc.tex` — documentation source (LuaLaTeX)
- `doc/latex/psalms/psalms-doc.pdf` — pre-built documentation

## Installation

1. Copy the `tex/latex/psalms/` and `tex/lualatex/psalms/` trees into your
   local TEXMF root (e.g. `~/Library/texmf` on macOS).
2. Refresh the filename database if your TeX distribution requires it.
3. Compile `doc/latex/psalms/psalms-doc.tex` with LuaLaTeX to regenerate the
   documentation PDF.

## Usage

Load the package in a LuaLaTeX document:

```latex
\documentclass{article}
\usepackage{fontspec}
\usepackage{psalms}
\begin{document}
\psalm{117}{8G}
\end{document}
```

Documentation covers package options for accent mode, verse numbering, Gloria
Patri inclusion, drop caps, and debugging.

## License

The package is distributed under the LaTeX Project Public License (LPPL)
version 1.3c; see `LICENSE`.
