# Psalms Package

Compilation of all 150 psalms in every tone with the first verse in Gregorian
notation and the remaining verses marked for chanting.

## Usage

```tex
\usepackage{psalms}

% Psalm 15 in mode 7c without the Gloria Patri
\psalm[ng]{15}{7c}
```

The optional argument selects the subdirectory: `g` (with Gloria, default) or
`ng` (no Gloria). The first mandatory argument is the psalm number and the
second is the psalm tone.

The package looks for matching score files in `gabc/` and corresponding verse
markup in the chosen mode directory.
