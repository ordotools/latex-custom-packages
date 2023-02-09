# LaTeX Custom Styles

A collection of custom style packages, designed for personal use.

## How to use (macOS guide)

There are a number of preparations that you must make in order that this work properly. Note that there are two ways
to install these custom style sheets: either for all users or for a particular user.

You must have MacTeX installed -- these instructions were tested on macOS Ventura with MacTeX 2022.

### Install for one user

Create directory `texmf` in `Library`:

```sh
mkdir ~/Library/texmf
```

Create a `tex` directory inside `texmf` as a GitHub repo:

```sh
cd ~/Library/texmf/
git init tex
cd tex
```

Now add the git repository. TeX live will find all the subdirectories inside `tex` and you can use any of the 
styles contained therein.

```sh
git remote add -f origin https://github.com/corei8/latex-custom-styles.git
```

*Skip the next section and continue to [ installation ]( #installation ).*

### Install for all users

TeX Live should already have this path waiting for you:

```sh
cd /usr/local/texlive/texmf-local
```

If it does not exist, then make the directory, and then repeat the above command:

```sh
mkdir /usr/local/texlive/texmf-local
```

Initialize the GitHub repo:

```sh
git init
```

Now add the git repository. TeX live will find all the subdirectories inside `texmf-local` and you can use any of the 
styles contained therein.

```sh
git remote add -f origin https://github.com/corei8/latex-custom-styles.git
```

### Installation

#### If you want to have only particular stylesheets

*Skip to the [ final step ]( #final-step ) if this is not for you.*

Run the command:

```sh
git config core.sparseCheckout true
```

Now you can select the directories that you want to install:

```sh
echo "some/dir/" >> .git/info/sparse-checkout
```

Repeat the above command, changing the directory as desired, for as many folders as you want to include.

#### Final step

Pull the repository with:

```sh
git pull origin main
```

### Updating

To get the latest version of the styles, you must first enter the directory (either `~/Library/texmf/tex` or `/usr/local/texlive/texmf-local`, depending), and then you 
have to execute `git pull origin main` again.





