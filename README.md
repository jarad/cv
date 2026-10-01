cv
==

My curriculum vitae.

The CV is built from CSV files in `data/`. `JaradNiemi-CV.Rnw` holds the
rendering logic and the few sections that are still written directly in LaTeX;
it contains no publication, presentation, grant, course, honour or service
content of its own.

## Layout

    data/                       the source of truth, one file per kind of record
      education.csv             degrees, theses and advisors
      positions.csv             academic appointments
      employment.csv            non-academic and pre-academic employment
      publications.csv          articles, with lifecycle status and output type
      presentations.csv         talks and posters
      grants.csv                funded projects, amounts and roles
      service.csv               profession, university and departmental service
      courses.csv               regular and short courses taught
      honors.csv                awards, with amounts and links
      memberships.csv           professional societies
      news.csv                  news interviews
      mentoring.csv             students mentored, e.g. Preparing Future Faculty
      people.csv                everyone the CV refers to, one row per person
      aliases.csv               the several ways a person's name may appear
      studentcommittees.csv     committees served on, keyed by person_id
      undergraduate_research.csv
    R/proof.R                   checks the data, the .tex and the LaTeX log
    JaradNiemi-CV.Rnw           rendering

## Quarto prototype

`cv.qmd` is a prototype of the same CV rendered by Quarto instead of LaTeX, so
one source gives a PDF (via Typst), a Word document and a web page. Every
section is ported; `JaradNiemi-CV.Rnw` still builds the LaTeX version from the
same data.

    cv.qmd                 the document: parameters and one chunk per section
    R/cv.R                 format-neutral helpers: Markdown escaping, dates,
                           bylines, and the emitters that write entries out
    R/sections.R           one function per section, CSV in, entries out
    cv-style/cv.lua        how each output format draws a row, a reference
                           list, a nested list, a table and the NEW tag
    cv-style/cv.typ        PDF styling and running header (cv.css for HTML)
    cv-style/make-reference-docx.py
                           builds reference.docx, the Word styles and header
    cv-style/keep-tables.py
                           keeps tables of up to 12 rows on one page in Word

    make quarto                       build everything below
    make quarto SINCE=2023-07-01      use a different review date

    cv.pdf  cv.docx  cv.html          the whole CV, clean
    cv-review.pdf  cv-review.docx     the whole CV, a NEW tag on what is new
    cv-new.docx                       only what is new, empty sections dropped

What counts as new is the `since` parameter (default 2022-01-01, the promotion
dossier). Set it to the date of the last review. The `mark` parameter is `none`
for the clean CV and `tag` for the review copy. Work that is not out yet is
left off unless asked for: `-P include_submitted:true` lists submitted and
under-revision articles, `-P include_inprep:true` those in preparation.

PDF and Word both put the name and "Page n / total" in a header from page 2
on, and never split an entry (an article, a talk, a row of dates and text, a
bullet) across a page; a long entry that does not fit moves whole to the next
page. A short table stays on one page; a long one breaks and repeats its
header. A section whose bylines carry a star says what it means.

A record is new if any day its date could denote is on or after `since`, so a
bare `2022` counts as new for a 1 July 2022 cutoff: better one old entry
flagged than a new one missed. Publications use `date_accepted`, then the
earlier of `date_online` and `date_print`, then `year`; work not yet out uses
`date_submitted`, then `date_last_activity`. Positions, employment, grants,
service and honors use `start_date`; talks and posters use `date`; a course
uses the end of its term; news uses `year`; a student committee is new if it
began or the student graduated since, and undergraduate research and
mentoring if they began or ended since. Memberships have no dates, so none is
ever new.

Book chapters, proceedings, abstracts, book reviews, patents and other
manuscripts live in `publications.csv` with their own `type`. They share one
shape, `authors. (year) title. details url`: `details` is whatever follows the
title (a venue in `*italics*`, editors, pages) and the byline is decorated like
any other. A preprint with no printed year leaves `year` blank and gives
`date_online`, which is also what decides whether it is new. The LaTeX build
still has these six lists written out by hand, so for now an edit to one of
them has to be made in both places.

Quarto is not installed on every machine; `pip install quarto-cli` is enough,
and `pip install python-docx` for the Word styles and `keep-tables.py`.

## Conventions

The CSVs hold **plain text**, never LaTeX. Escaping, bolding my name, starring
advisees and italics all happen at render time, so a name spelling or an
em-dash is a data change rather than a code change. Emphasis that carries
meaning, such as a species name, is written in Markdown (`*Drosophila*`).

Dates are **ISO 8601** at whatever precision is actually known: `2024`,
`2024-06`, or `2024-06-15`. Never invent a day to make a column uniform. The
CV prints years, and a span of two consecutive years prints as an academic
year, `AY18-19`. Exact dates matter beyond the CV itself: annual review runs
on a fiscal year (July-June), so a role's actual start or end date decides
which review it falls under in a way a bare year cannot. Backfill exact
dates when they can be found (email, offer letters, meeting minutes), and
prioritize anything currently ongoing (a blank `end_date`) since that is
what a future review will need.

`studentcommittees.csv` tracks a committee relationship's `start_date` and
`end_date` separately from `graduation_date`: a student can leave a
committee (or Niemi can roll off it) without the student graduating, and a
blank `graduation_date` means the degree is still in progress regardless of
whether the committee relationship itself has ended.

People are referenced by `person_id`, never by repeating a name. Because the
same person may be published under several spellings, `aliases.csv` records
them; matching respects author boundaries, since "J. Niemi" is a substring of
"Gerald J. Niemi", who is a different person.

The `notes` column is shown to the reader; `internal_notes` is not.

## Building

    make            rebuild the PDF and proofread it
    make proof      proofread whatever was last built
    make clean      remove build artefacts

`R/proof.R` exits non-zero if anything is wrong. It checks that the data is
plain text, that every record reaches the page, that no internal note leaks
into it, that names are decorated correctly and only for the right people, and
that LaTeX reported no errors *or overfull boxes* — the latter being warnings
rather than errors, and so easy to miss.

## Not pushing a broken CV

`.githooks/pre-push` rebuilds the CV, runs the proofreader, and refuses the
push if either fails or if the committed PDF does not match the sources being
pushed. Enable it once per clone:

    git config core.hooksPath .githooks

That configuration is local to a clone and is not itself cloned, so a fresh
checkout has no gate until the line above is run. `git push --no-verify`
bypasses it when necessary.

The staleness check works because builds are byte-reproducible: `pdflatex`
would otherwise stamp the current time into the PDF, so two identical builds
would differ. The `Makefile` pins `SOURCE_DATE_EPOCH`, which fixes the date
recorded in the PDF metadata and makes an unchanged source always produce an
identical file.

The proofreader catches mechanical faults, not prose. Read the PDF before
sending it anywhere.

## Student committees

Visit the [Graduate Faculty Database](https://secure.grad-college.iastate.edu/tools/graduate/grad-faculty/view/?id=4269527)
and export student committees. The export covers current students only, so the
rest of `data/studentcommittees.csv` is maintained by hand.
