SDU Thesis Template
===================

This is a LaTeX template for BSc and MSc projects at the University of
Southern Denmark.

Here's a couple of relevant LaTeX resources:

- [The TeX FAQ](http://www.texfaq.org/)
- [Lars Madsen's LaTeX book (in Danish)](https://math.medarbejdere.au.dk/latex/bog/)


Compilation instructions
------------------------

To compile the document locally first install LaTeX.

You can now run:
  ```
    pdflatex main
    bibtex main
    pdflatex main
    pdflatex main
  ```

Alternatively you can use `latexmk`:
  ```
    latexmk -pdf main && open "/Users/nick/Documents/AAVE-module/report/template/main.pdf"
  ```

Another alternative is to install `make` and simply run it.

You can share your LaTeX source code via git.

Alternatively you can use Overleaf.


Adjustment instructions
-----------------------

To adjust the template:
- Adjust the names, date, and type of thesis on `frontpage.tex`
- Adjust the abstract in `abstract.tex`
- Each chapter resides in a separate file:
  ```
    chap-introduction.tex
    chap-background.tex
    ...
    chap-conclusion.tex
  ```
  These are included from `main.tex`.
  Adjust the chapters and files to your liking.
- The bibliography uses Bibtex. The entries are in `mybibliography.bib`.
  Adjust these to fit your content.
