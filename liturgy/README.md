# Liturgical Booklet Package

A LaTeX package for building small liturgical booklets with chant notation.

## Features

- Sets up a compact page layout and basic fonts.
- Integrates with GregorioTeX for chant scores.
- Provides helper commands for colored text, rubrics, versicles, psalms and canticles.
- Includes macros for lessons, responsories and prayers used in Tenebræ booklets.

## Usage

```tex
\usepackage{liturgicalbooklet}

% Create a title page with an image
\mytitle{Good Friday}{cover-image.png}

% Build Psalm 15 in mode 7c without the Gloria
\buildpsalm{antiphon-file}{15}{7c}
```

See the package source for the full list of commands.
