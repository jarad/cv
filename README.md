cv
==

My curriculum vitae.

The CV is built from CSV files in `data/`. `JaradNiemi-CV.Rnw` holds the
rendering logic and the few sections that are still written directly in LaTeX;
it contains no publication, presentation, grant, course, honour or service
content of its own.

## Layout

    data/                       the source of truth, one file per kind of record
      publications.csv          articles, with lifecycle status and output type
      presentations.csv         talks and posters
      grants.csv                funded projects, amounts and roles
      service.csv               profession, university and departmental service
      courses.csv               regular and short courses taught
      honors.csv                awards, with amounts and links
      memberships.csv           professional societies
      mentoring.csv             students mentored, e.g. Preparing Future Faculty
      people.csv                everyone the CV refers to, one row per person
      aliases.csv               the several ways a person's name may appear
      studentcommittees.csv     committees served on, keyed by person_id
      undergraduate_research.csv
    R/proof.R                   checks the data, the .tex and the LaTeX log
    JaradNiemi-CV.Rnw           rendering

## Conventions

The CSVs hold **plain text**, never LaTeX. Escaping, bolding my name, starring
advisees and italics all happen at render time, so a name spelling or an
em-dash is a data change rather than a code change. Emphasis that carries
meaning, such as a species name, is written in Markdown (`*Drosophila*`).

Dates are **ISO 8601** at whatever precision is actually known: `2024`,
`2024-06`, or `2024-06-15`. Never invent a day to make a column uniform. The
CV prints years, and a span of two consecutive years prints as an academic
year, `AY18-19`.

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
