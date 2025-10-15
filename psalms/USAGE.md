# Psalms Package Usage Guide

The `psalms.sty` package provides automatic typesetting of Latin psalms with Gregorian chant tone markings.

## Requirements

- LuaLaTeX (required for Lua module support)
- `fontspec` package
- `babel` package with Latin support
- `xparse` package

## Basic Usage

### Loading the Package

```latex
\documentclass{article}
\usepackage{psalms}
\setmainfont{Latin Modern Roman}

\begin{document}
\psalm{117}{8G}  % Psalm 117 with Tone 8G
\end{document}
```

### Command Syntax

```latex
\psalm{<number>}{<mode>}
```

- `<number>`: Psalm number (1-150)
- `<mode>`: Tone preset (e.g., 1, 2D, 3, 4, 5, 6, 7, 8G)

## Package Options

### Accent Mode Options

```latex
% Use orthographic accent mode (looks for acute marks in text)
\usepackage[orthographic]{psalms}

% Use positional accent mode (default - penultimate syllable)
\usepackage[positional]{psalms}
```

### Debug Option

```latex
% Enable debug output to .log file
\usepackage[debug]{psalms}
```

This will output syllabification information to the log file for debugging purposes.

## Available Tone Presets

- `1` - Tone 1
- `2D` - Tone 2D
- `3` - Tone 3
- `4` - Tone 4
- `5` - Tone 5
- `6` - Tone 6
- `7` - Tone 7
- `8G` - Tone 8G

## Inline Accent Mode Control

You can change the accent mode within your document:

```latex
\SetPsalmAccentMode{orthographic}
\psalm{117}{8G}

\SetPsalmAccentMode{positional}
\psalm{150}{2D}
```

## Testing Individual Lines

For testing or ad-hoc use, you can process individual lines:

```latex
\PsalmLine{Beatus vir qui non abiit * et in via peccatorum non stetit.}\par
```

## Customization

### Styling

You can customize the appearance of different syllable types:

```latex
\renewcommand*\PsalmStyleAccent{\bfseries\color{red}}  % Accent syllables
\renewcommand*\PsalmStylePrep{\itshape}                % Preparatory syllables
\renewcommand*\PsalmStyleOther{}                        % Other syllables
```

### File Locations

By default, psalm text files are expected in the `psalms/` directory with `.txt` extension:

```latex
\renewcommand*\PsalmDir{my-psalms}  % Change directory
\renewcommand*\PsalmExt{txt}        % Change extension
```

### Divider and Joiner

```latex
\renewcommand*\PsalmHalfDivider{*}  % Character dividing verse halves
\renewcommand*\PsalmJoiner{-}       % Character joining syllables (for debugging)
```

## Example Files

See the included example files for complete demonstrations:

- `example_usage.tex` - Basic usage examples with different tones
- `example_options.tex` - Package options demonstration
- `example_debug.tex` - Debug mode example

## Legacy Command

For backward compatibility, the old command format is available as `\psalmlegacy`:

```latex
\psalmlegacy[8G]{117}  % Old format: [preset]{number}
```

## Notes

- Psalm text files should use UTF-8 encoding
- The asterisk (*) divides verse halves (mediant and termination)
- Syllabification uses improved Latin rules with proper handling of diphthongs and consonant clusters
- Orthographic mode looks for acute accents (á, é, í, ó, ú) in the source text
- Positional mode (default) accents the penultimate syllable of each word

