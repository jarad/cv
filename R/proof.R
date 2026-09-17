# Proofreads the generated CV. Run after knitting and compiling:
#
#   Rscript -e 'library(knitr); knit("JaradNiemi-CV.Rnw")'
#   pdflatex JaradNiemi-CV.tex && pdflatex JaradNiemi-CV.tex
#   Rscript R/proof.R
#
# Exits non-zero if anything is wrong, so it can gate a commit or a CI run.
# It checks three separate things, because each has let a defect through:
#   1. the data,  before rendering  (LaTeX where plain text belongs)
#   2. the .tex,  after rendering   (mangled macros, stray NA, lost records)
#   3. the .log,  after typesetting (overfull boxes, which are not errors)

suppressMessages(library(tidyverse))

problems <- 0L
report <- function(ok, label, detail = NULL) {
  cat(sprintf("  [%s] %s\n", if (ok) "ok  " else "FAIL", label))
  if (!ok) {
    problems <<- problems + 1L
    if (!is.null(detail)) for (d in head(detail, 8)) cat("        ", str_trunc(d, 100), "\n")
  }
}

# ---- 1. the data should be plain text -------------------------------------
cat("\ndata\n")
for (f in list.files(".", pattern = "\\.csv$")) {
  d <- suppressWarnings(read_csv(f, show_col_types = FALSE, progress = FALSE))
  bad <- character(0)
  for (col in setdiff(names(d), c("url", "notes_url", "doi", "pre-print", "website",
                                  "linkedin", "orcid", "internal_notes"))) {
    v <- as.character(d[[col]])
    k <- which(!is.na(v) & str_detect(v, "\\\\|\\{|\\}|\\$\\^"))
    if (length(k)) bad <- c(bad, paste0(col, ": ", v[k]))
  }
  report(!length(bad), paste0(f, " holds plain text"), bad)
}

# ---- 2. the rendered .tex --------------------------------------------------
cat("\nrendered output\n")
tex <- readLines("JaradNiemi-CV.tex", warn = FALSE)

k <- grep("textbackslash", tex)
report(!length(k), "no escaped-macro wreckage (textbackslash)", tex[k])

k <- grep("(^|[ (>{])NA([ ),.}]|$)", tex)
report(!length(k), "no stray NA in output", tex[k])

k <- grep("^\\\\item\\s*$", tex)
report(!length(k), "no empty list items", tex[k])

# internal annotations must never reach the page
internal <- c()
for (f in list.files(".", pattern = "\\.csv$")) {
  d <- suppressWarnings(read_csv(f, show_col_types = FALSE, progress = FALSE))
  if ("internal_notes" %in% names(d)) internal <- c(internal, na.omit(d$internal_notes))
}
leaked <- internal[map_lgl(internal, ~ any(str_detect(tex, fixed(.x))))]
report(!length(leaked), "no internal notes leaked into the CV", leaked)

# every record in the data should appear in the output
counts <- function(from, to) {
  a <- grep(from, tex); if (!length(a)) return(character(0))
  b <- grep(to, tex); b <- b[b > a[1]]
  tex[a[1]:(if (length(b)) b[1] else length(tex))]
}
pres <- read_csv("presentations.csv", show_col_types = FALSE)
report(sum(grepl("^``", counts("\\\\section\\{\\\\bf Talks\\}", "\\\\section\\{\\\\bf Posters\\}"))) ==
         sum(pres$kind == "talk"), "every talk rendered")
gr <- read_csv("grants.csv", show_col_types = FALSE)
report(sum(grepl("^\\\\item", counts("\\\\section\\{\\\\bf Grants\\}", "\\\\section\\{\\\\bf Honors"))) ==
         nrow(gr), "every grant rendered")
ho <- read_csv("honors.csv", show_col_types = FALSE)
report(sum(grepl("^\\\\item", counts("\\\\section\\{\\\\bf Honors", "\\\\section\\{\\\\bf Memberships"))) ==
         nrow(ho), "every honor rendered")
co <- read_csv("courses.csv", show_col_types = FALSE)
report(sum(grepl("&.*&", counts("\\\\section\\{\\\\bf Courses taught\\}", "\\\\section\\{\\\\bf Grants\\}"))) ==
         nrow(co), "every course rendered")

# advisee stars and my own name should be decorated everywhere they appear
pp <- read_csv("people.csv", show_col_types = FALSE)
al <- read_csv("aliases.csv", show_col_types = FALSE)
sc <- read_csv("studentcommittees.csv", show_col_types = FALSE)
advisees <- sc |> filter(!is.na(Chair)) |> distinct(person_id) |> pull(person_id)
spell <- bind_rows(pp |> transmute(person_id, s = name), al |> transmute(person_id, s = alias))
# only where names appear as bylines: the advisee and committee tables list
# the same people deliberately undecorated
bylines <- counts("\\\\section\\{Publications\\}", "\\\\section\\{\\\\bf News")
rx_esc <- function(s) {
  for (ch in c("\\", ".", "|", "(", ")", "[", "]", "{", "}", "^", "$", "*", "+", "?"))
    s <- gsub(ch, paste0("\\", ch), s, fixed = TRUE)
  s
}
undec <- character(0)
for (i in seq_len(nrow(spell))) {
  s <- spell$s[i]; pid <- spell$person_id[i]
  if (!(pid %in% c("jarad-niemi", advisees))) next
  want <- if (pid == "jarad-niemi") paste0("{\\bf ", s, "}") else paste0(s, "*")
  # count only occurrences at an author boundary, mirroring decorate_authors,
  # so "J. Niemi" inside "Gerald J. Niemi" is not treated as a missed name
  at_boundary <- paste0("(^|,\\s*|\\s+and\\s+|\\(\\s*)", rx_esc(s), "(?=$|[,.;)]|\\s)")
  hits <- grep(fixed(s), bylines, fixed = TRUE)
  for (h in hits) {
    line <- bylines[h]
    n_all <- str_count(line, regex(at_boundary))
    n_ok  <- str_count(line, fixed(want))
    if (n_all > n_ok) undec <- c(undec, paste0(s, " -> ", str_trunc(line, 80)))
  }
}
report(!length(undec), "advisees starred and my name bolded throughout", unique(undec))

# ---- 3. typesetting --------------------------------------------------------
cat("\ntypesetting\n")
log <- readLines("JaradNiemi-CV.log", warn = FALSE)
k <- grep("^!", log)
report(!length(k), "no LaTeX errors", log[k])
k <- grep("^(Overfull|Underfull)", log)
report(!length(k), "no overfull or underfull boxes", log[k])
k <- grep("Reference .* undefined|Citation .* undefined", log)
report(!length(k), "no undefined references", log[k])

cat(sprintf("\n%d problem(s)\n", problems))
quit(status = if (problems) 1 else 0)
