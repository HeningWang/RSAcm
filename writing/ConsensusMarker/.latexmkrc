# .latexmkrc
# Route all auxiliary / cache files to build/ while keeping the PDF
# in the same directory as the source .tex file.
#
# Usage:
#   latexmk -pdf main.tex          # compile with aux in build/
#   latexmk -pdf -pvc main.tex     # continuous preview mode
#   latexmk -C                     # clean build/ directory

$aux_dir = 'build';   # .aux, .log, .bbl, .bcf, .run.xml, etc. → build/
$out_dir = '.';       # compiled .pdf stays next to the .tex file

# Use pdflatex (change to 'lualatex' or 'xelatex' if needed)
$pdf_mode = 1;
$pdflatex = 'pdflatex -interaction=nonstopmode -synctex=1 %O %S';

# biber for biblatex (as used in this project).
# latexmk 4.83 handles aux_dir paths for biber automatically.
$bibtex_use = 2;
