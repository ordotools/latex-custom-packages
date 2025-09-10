# Rubrics Package

Typesetting support for liturgical ceremony notes with red rubric text.

## Features

- Sets up Minion3 as the main font and defines a matching red color.
- Configures page geometry and two-column layout for compact notes.
- Optional `chant` and `final` package options load `gregoriotex` and `microtype` respectively.
- Commands for numbered rubrics: `\rubric`, `\rubricC`, `\rubricD`, and `\rubricSD`.
- Helper symbols like `\cross`, `\rbar`, and `\vbar` for liturgical cues.

## Usage

```tex
\usepackage[chant]{rubrics}

\rubric The celebrant kneels.
```
