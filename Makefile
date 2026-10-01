# Build and check the CV.
#
#   make          rebuild the PDF and proofread it
#   make proof    proofread whatever was last built
#   make clean    remove build artefacts
#
# Builds are byte-reproducible: pdflatex normally stamps the current time into
# the PDF, so two identical builds would differ. Pinning SOURCE_DATE_EPOCH
# means an unchanged source always produces an identical PDF, which is what
# lets the pre-push hook tell "the committed PDF matches the sources" from
# "someone edited the data and forgot to rebuild".
export FORCE_SOURCE_DATE = 1
export SOURCE_DATE_EPOCH = 1700000000

RNW  = JaradNiemi-CV.Rnw
TEX  = JaradNiemi-CV.tex
PDF  = JaradNiemi-CV.pdf
DATA = $(wildcard data/*.csv)

.PHONY: all proof clean quarto

all: $(PDF)

$(PDF): $(RNW) $(DATA) res.cls
	Rscript -e 'library(knitr); knit("$(RNW)", quiet = TRUE)'
	pdflatex -interaction=nonstopmode $(TEX) > /dev/null
	pdflatex -interaction=nonstopmode $(TEX) > /dev/null
	@$(MAKE) --no-print-directory proof

proof:
	@Rscript R/proof.R

clean:
	rm -rf cache $(TEX) JaradNiemi-CV.aux JaradNiemi-CV.log \
	       JaradNiemi-CV.out JaradNiemi-CV-concordance.tex

# Prototype: the Quarto build.
#   cv.pdf cv.docx cv.html   the whole CV, clean
#   cv-review.pdf/.docx      the whole CV with a NEW tag on what is new
#   cv-new.docx              only what is new
# "New" is everything on or after SINCE, the date of the last review:
#   make quarto SINCE=2023-07-01
# Quarto writes each render to cv.<ext> and then renames it for --output, so
# the variants go first and the plain build last.
SINCE ?= 2022-01-01
quarto:
	quarto render cv.qmd --to docx -P since:$(SINCE) -P new_only:true --output cv-new.docx
	quarto render cv.qmd --to typst -P since:$(SINCE) -P mark:tag --output cv-review.pdf
	quarto render cv.qmd --to docx -P since:$(SINCE) -P mark:tag --output cv-review.docx
	quarto render cv.qmd -P since:$(SINCE)
