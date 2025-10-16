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

### Verse Numbers Option

```latex
% Enable verse numbers for all psalms
\usepackage[versenumbers]{psalms}
```

This will display verse numbers for each verse in the psalm. You can also enable/disable verse numbers inline:

```latex
\SetPsalmVerseNumbers{true}   % Enable verse numbers
\psalm{117}{8G}
\SetPsalmVerseNumbers{false}  % Disable verse numbers
```

You can customize the verse number style using `\SetPsalmVerseStyle`:

```latex
\SetPsalmVerseStyle{label=\Roman*.,leftmargin=2em,itemsep=1ex}
```

### Gloria Patri Option

```latex
% Enable Gloria Patri at the end of all psalms
\usepackage[gloriapatri]{psalms}
```

This will automatically append the Gloria Patri doxology at the end of each psalm. You can also control it inline:

```latex
\SetPsalmGloriaPatri{true}   % Enable Gloria Patri
\psalm{117}{8G}
\SetPsalmGloriaPatri{false}  % Disable Gloria Patri
```

### Dropcap Option

```latex
% Enable dropcap (large initial letter) for the first verse
\usepackage[dropcap]{psalms}
```

This will use the `lettrine` package to create a decorative drop capital for the first letter of the first verse. When used with verse numbers, the numbering automatically starts at 2 for the second verse.

You can control dropcaps inline:

```latex
\SetPsalmDropcap{true}   % Enable dropcap
\psalm{117}{8G}
\SetPsalmDropcap{false}  % Disable dropcap
```

#### Customizing Dropcap Style

You can customize the appearance of the dropcap by redefining the dropcap parameter commands:

```latex
% Set dropcap to span 3 lines with hanging and size adjustments
\renewcommand*\PsalmDropcapLines{3}
\renewcommand*\PsalmDropcapLhang{0.3}
\renewcommand*\PsalmDropcapLoversize{0.1}
\renewcommand*\PsalmDropcapLraise{0}
```

Available dropcap parameters:
- `lines`: Number of lines the dropcap should span (default: 2)
- `lhang`: Horizontal hanging of the dropcap into the margin (0-1, default: 0)
- `loversize`: Size adjustment for the dropcap (default: 0)
- `lraise`: Vertical adjustment for the dropcap (default: 0)

#### Combined Options

You can combine multiple package options:

```latex
% Enable verse numbers, Gloria Patri, and dropcap
\usepackage[versenumbers,gloriapatri,dropcap]{psalms}
```

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
- `example_dropcap.tex` - Dropcap feature demonstration with various styles

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

