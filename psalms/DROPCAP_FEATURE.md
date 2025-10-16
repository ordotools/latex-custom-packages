# Dropcap Feature

## Overview

The psalms package now supports drop capitals (large decorative initial letters) for the first verse using the lettrine package. When combined with verse numbering, the numbering automatically starts at 2 for the second verse.

## Basic Usage

### Enable dropcap globally

```latex
\usepackage[dropcap]{psalms}
```

### Enable/disable dropcap inline

```latex
\SetPsalmDropcap{true}   % Enable
\psalm{117}{8G}
\SetPsalmDropcap{false}  % Disable
```

## Customizing Dropcap Style

Customize the appearance by redefining these commands:

```latex
\renewcommand*\PsalmDropcapLines{3}        % Lines to span (default: 2)
\renewcommand*\PsalmDropcapLhang{0.3}      % Hanging into margin (default: 0)
\renewcommand*\PsalmDropcapLoversize{0.1}  % Size adjustment (default: 0)
\renewcommand*\PsalmDropcapLraise{0}       % Vertical adjustment (default: 0)
```

## Combining with Other Options

```latex
% Dropcap with verse numbers and Gloria Patri
\usepackage[dropcap,versenumbers,gloriapatri]{psalms}
```

When verse numbers are enabled, the first verse with dropcap appears without a number, and numbering starts at 2.

## Example

See `example_dropcap.tex` for comprehensive examples demonstrating:
- Basic dropcap usage
- Dropcap with verse numbers
- Customized dropcap styles
- Combining dropcap with Gloria Patri
- Enabling/disabling dropcap inline

## Implementation Details

- Uses the lettrine package for dropcap rendering
- Extracts the first character of the first verse (with automatic UTF-8 BOM handling)
- Extracts the first word as plain text for lettrine's second argument
- Applies psalm tone styling to the rest of the text
- Automatically adjusts enumerate counter when verse numbers are enabled (starts at 2)
- Supports both syllabified and non-syllabified text
- Compatible with UTF-8 encoded text files including accented characters

