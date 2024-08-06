# LaTeX Custom Styles

A collection of custom style packages, designed for personal use.

- [Psalms](#psalms-package)

## How to use (macOS guide)

There are a number of preparations that you must make in order that this work properly. Note that there are two ways
to install these custom style sheets: either for all users or for a particular user.

You must have MacTeX installed -- these instructions were tested on macOS Ventura with MacTeX 2022.

### Install for one user

Create directory `texmf` in `Library`:

```zsh
mkdir ~/Library/texmf
```

Create a `tex` directory inside `texmf` as a GitHub repo:

```zsh
cd ~/Library/texmf/
git init tex
cd tex
```

Now add the git repository. TeX live will find all the subdirectories inside `tex` and you can use any of the 
styles contained therein.

```zsh
git remote add -f origin https://github.com/corei8/latex-custom-styles.git
```

*Skip the next section and continue to [ installation ]( #installation ).*

### Install for all users

TeX Live should already have this path waiting for you:

```zsh
cd /usr/local/texlive/texmf-local
```

If it does not exist, then make the directory, and then repeat the above command:

```zsh
mkdir /usr/local/texlive/texmf-local
```

Initialize the GitHub repo:

```zsh
git init
```

Now add the git repository. TeX live will find all the subdirectories inside `texmf-local` and you can use any of the 
styles contained therein.

```zsh
git remote add -f origin https://github.com/corei8/latex-custom-styles.git
```

### Installation

#### If you want to have only particular stylesheets

*Skip to the [ final step ]( #final-step ) if this is not for you.*

Run the command:

```zsh
git config core.sparseCheckout true
```

Now you can select the directories that you want to install:

```zsh
echo "some/dir/" >> .git/info/sparse-checkout
```

Repeat the above command, changing the directory as desired, for as many folders as you want to include.

#### Final step

Pull the repository with:

```zsh
git pull origin main
```

### Updating

To get the latest version of the styles, you must first enter the directory (either `~/Library/texmf/tex` or `/usr/local/texlive/texmf-local`, depending), and then you 
have to execute `git pull origin main` again.

---

## Psalms Package

A very opinionated command:

```tex
\psalm[<gloria/no gloria>][<title>]{<psalm>}{<mode>}
```

For example, ```\psalm[ng]{15}{7c}``` will set psalm XV to 7c without a Gloria.
This command in itself, though opinionated, can be used with other commands to
great effect. Here is an example from my
[chant](https://github.com/corei8/chant) repository:

```tex
\newcounter{antiphon}\setcounter{antiphon}{1}
\newcounter{allantiphon}\setcounter{allantiphon}{1}

\newcommand{\buildpsalm}[3]{
	\ifnum \value{allantiphon}=10 {\setcounter{antiphon}{1}} \fi
	\gresetannotationvalign{bottom}
	\greannotation{Ant. \theantiphon}
	\gresetgregpath{{./antiphons/}}
	\greannotation{#3}
	\gregorioscore{#1}
	\subsection{Psalm #2.}
	\gresetinitiallines{0}
	\psalm[ng]{#2}{#3}
	\stepcounter{antiphon}
	\stepcounter{allantiphon}
	\gresetinitiallines{1}
	}
```

**NOTE**

Other options will be added as needed/requested (e.g., no color, no psalm
title, numbers, etc.). There are still a few problems with the psalms, as I did
not write the parser myself. Some of the more obscure tones are missing and
there are some unusual renditions of others. I will be working on those soon
and will perhaps be writing my own parser. To my knowledge, the text of the
psalms is perfect, and much work has been done to get rid of some of the
nuances that were present. bringing to my attention any typos that you may find
will be much appreciated.
