# Format-neutral building blocks for the Quarto CV.
#
# The CSVs hold plain text. Everything below turns a record into *Markdown*,
# never into LaTeX, so Pandoc can send the same text to Typst, Word or HTML.
# A section is a data frame of entries; how an entry looks is decided by the
# emitters at the bottom and by the per-format styling, not by the data.
#
#   entry columns   label    left-hand text (dates), used by rows layouts
#                   body     the entry itself, as Markdown
#                   new_date the date that decides whether it is new
#                   group    optional heading to gather rows under
#
# "New" means: not part of the previous review. See is_new().

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
})

# ---- text ------------------------------------------------------------------

# Escape the characters Pandoc would otherwise read as Markdown. Quarto also
# parses @ as a citation and $...$ as maths, so both are escaped.
md_escape = function(x) gsub("([\\\\`*_\\[\\]<>$@^~|#{}])", "\\\\\\1", x, perl = TRUE)

# Plain text -> Markdown, except that `*emphasis*` passes through: the data
# writes meaningful italics (a species name) that way. A stray star is literal.
md_text = function(x) {
  vapply(x, function(s) {
    if (is.na(s)) return(NA_character_)
    # one title still carries TeX quotes, ``like this'' (data/publications.csv)
    s = gsub("``([^']*)''", "\u201c\\1\u201d", s)
    s = gsub("\\*([^*]+)\\*", "\001\\1\002", s)
    s = md_escape(s)
    s = gsub("\001", "*", s, fixed = TRUE)
    gsub("\002", "*", s, fixed = TRUE)
  }, character(1), USE.NAMES = FALSE)
}

# ---- dates -----------------------------------------------------------------

# Partial ISO 8601 ("2020", "2020-10", "2020-10-05") -> the earliest and the
# latest day it could denote.
iso_floor = function(x) {
  x = as.character(x)
  as.Date(ifelse(is.na(x), NA_character_,
         ifelse(grepl("^\\d{4}$", x),        paste0(x, "-01-01"),
         ifelse(grepl("^\\d{4}-\\d{2}$", x), paste0(x, "-01"), x))))
}
iso_ceil = function(x) {
  x = as.character(x)
  out = iso_floor(x)
  yr = !is.na(x) & grepl("^\\d{4}$", x)
  mo = !is.na(x) & grepl("^\\d{4}-\\d{2}$", x)
  # paste0() on an empty vector still returns one string, hence the guards
  if (any(yr)) out[yr] = as.Date(paste0(x[yr], "-12-31"))
  if (any(mo)) out[mo] = as.Date(vapply(out[mo], function(d)
    as.numeric(seq(d, by = "month", length.out = 2)[2] - 1), numeric(1)))
  out
}

# A date known only to the year or month is "new" if any day it could denote
# is on or after the cutoff: a reviewer would rather see one old item flagged
# than miss one new one.
is_new = function(date, since) {
  d = iso_ceil(date)
  !is.na(d) & d >= as.Date(since)
}

# 2018 | AY18-19 | 2011--2022 | 2020--present
span = function(s, e, academic = TRUE) {
  s = as.integer(substr(s, 1, 4)); e = as.integer(substr(e, 1, 4))
  mapply(function(s1, e1) {
    if (is.na(s1))                 return(NA_character_)
    if (is.na(e1))                 return(paste0(s1, "–present"))
    if (e1 == s1)                  return(as.character(s1))
    if (academic && e1 == s1 + 1)  return(sprintf("AY%02d-%02d", s1 %% 100, e1 %% 100))
    paste0(s1, "–", e1)
  }, s, e)
}

# Iowa State's annual review follows the fiscal year, July-June. "FY2025" is
# 1 July 2024 -- 30 June 2025. Handy for -P since=...
fy_start = function(fy) as.Date(sprintf("%d-07-01", as.integer(fy) - 1))

# ---- people and bylines ----------------------------------------------------

load_people = function(dir = "data") {
  people  = read_csv(file.path(dir, "people.csv"),  show_col_types = FALSE)
  aliases = read_csv(file.path(dir, "aliases.csv"), show_col_types = FALSE)
  committees = read_csv(file.path(dir, "studentcommittees.csv"), show_col_types = FALSE)
  spellings = bind_rows(
    people  |> transmute(person_id, spelling = name),
    aliases |> transmute(person_id, spelling = alias))
  list(
    spellings = spellings[order(-nchar(spellings$spelling)), ],   # longest first
    # chair or co-chair both count as having advised the student
    advisee_ids = unique(committees$person_id[!is.na(committees$Chair)]))
}

rx_escape = function(s) {
  for (ch in c("\\", ".", "|", "(", ")", "[", "]", "{", "}", "^", "$", "*", "+", "?"))
    s = gsub(ch, paste0("\\", ch), s, fixed = TRUE)
  s
}

# Bold my own name; star advisees. A spelling only counts at an author
# boundary, so "J. Niemi" does not match inside "Gerald J. Niemi".
decorate_authors = function(s, ppl) {
  if (is.na(s)) return(s)
  out = md_escape(s)
  for (i in seq_len(nrow(ppl$spellings))) {
    pid = ppl$spellings$person_id[i]
    esc = md_escape(ppl$spellings$spelling[i])
    if (!grepl(esc, out, fixed = TRUE)) next
    rep = if (pid == "jarad-niemi")           paste0("**", esc, "**")
          else if (pid %in% ppl$advisee_ids)  paste0(esc, "\\*")
          else next
    pat = paste0("(^|,\\s*|\\s+and\\s+|\\(\\s*)", rx_escape(esc), "(?=$|[,.;)]|\\s)")
    out = gsub(pat, paste0("\\1", gsub("\\\\", "\\\\\\\\", rep)), out, perl = TRUE)
  }
  out
}

# ---- emitters ---------------------------------------------------------------

# Parameters arrive from `quarto render -P`. Everything downstream reads this.
cv_options = function(params) {
  list(since    = as.Date(params$since),
       new_only = isTRUE(as.logical(params$new_only)),
       # how "new" is shown in the full CV: "tag" (a NEW label on each entry),
       # "divider" (one line where a sorted list crosses the cutoff) or "none"
       mark     = params$mark %||% "tag")
}
`%||%` = function(a, b) if (is.null(a)) b else a

NEW_TAG = "[NEW]{.cv-new} "

cv_divider = function(opt) {
  cat("\n::: {.cv-divider}\n",
      "Entries above are new since ", format(opt$since, "%e %B %Y") |> trimws(),
      ".\n:::\n\n", sep = "")
}

cv_heading = function(title) cat("\n\n## ", title, "\n\n", sep = "")

# Drop what is not new when producing the "only what is new" document, and
# report whether anything is left, so empty sections can disappear.
apply_view = function(e, opt) if (opt$new_only) e[e$is_new, , drop = FALSE] else e

# A flat list of references: authors, titles, talks. Hanging indent comes
# from the format-specific styling of `.cv-list`.
emit_list = function(e, title, opt, subtitle = NULL) {
  e = apply_view(e, opt)
  if (!nrow(e)) return(invisible(FALSE))
  cv_heading(title)
  if (!is.null(subtitle)) cat("### ", subtitle, "\n\n", sep = "")
  # new entries first, then one divider, then the rest: each group keeps the
  # order it arrived in
  e = e[order(!e$is_new), , drop = FALSE]
  cat("::: {.cv-list custom-style=\"CV Entry\"}\n\n")
  crossed = FALSE
  for (i in seq_len(nrow(e))) {
    if (opt$mark == "divider" && !opt$new_only && !crossed && i > 1 && !e$is_new[i] && e$is_new[i - 1]) {
      cat(":::\n"); cv_divider(opt); cat("::: {.cv-list custom-style=\"CV Entry\"}\n\n")
      crossed = TRUE
    }
    tag = if (opt$mark == "tag" && !opt$new_only && e$is_new[i]) NEW_TAG else ""
    cat(tag, e$body[i], "\n\n", sep = "")
  }
  cat(":::\n\n")
  invisible(TRUE)
}

# Date (or other short label) at the left, text at the right. Written as a
# Markdown definition list; `cv.lua` turns it into a borderless two-column
# table, which every output format draws natively.
emit_rows = function(e, title, opt) {
  e = apply_view(e, opt)
  if (!nrow(e)) return(invisible(FALSE))
  cv_heading(title)
  groups = if ("group" %in% names(e)) unique(e$group) else NA
  for (g in groups) {
    d = if (is.na(g)) e else e[e$group == g, , drop = FALSE]
    if (!is.na(g)) cat("**", g, "**\n\n", sep = "")
    cat("::: {.cv-rows}\n\n")
    for (i in seq_len(nrow(d))) {
      tag = if (opt$mark != "none" && !opt$new_only && d$is_new[i]) NEW_TAG else ""
      cat(d$label[i], "\n:   ", tag, gsub("\n", "\n    ", d$body[i]), "\n\n", sep = "")
    }
    cat(":::\n\n")
  }
  invisible(TRUE)
}
