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
#                   category the heading above a nested list (tree layout)
#
# A section is a heading and one or more parts; a part is entries plus the
# layout to draw them in: list, rows, tree or table (see emit_section).
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
  flag = function(x) isTRUE(as.logical(x))
  list(since    = as.Date(params$since),
       new_only = flag(params$new_only),
       # "tag" puts a NEW label on each new entry of the full CV; "none" (the
       # default) leaves the full CV clean, with everything and no flags
       mark     = params$mark %||% "none",
       # work that is not yet out is listed only when asked for, usually
       # close to a promotion case
       include_submitted = flag(params$include_submitted),
       include_inprep    = flag(params$include_inprep))
}
`%||%` = function(a, b) if (is.null(a)) b else a

NEW_TAG = "[NEW]{.cv-new} "
new_tag = function(opt, is_new)
  if (opt$mark == "tag" && !opt$new_only && isTRUE(is_new)) NEW_TAG else ""

# Printed under the heading of every section whose bylines carry the star.
ADVISEE_NOTE = "\\* Indicates a student advisee or co-advisee."

cv_heading = function(title) cat("\n\n## ", title, "\n\n", sep = "")

# Drop what is not new when producing the "only what is new" document.
apply_view = function(e, opt) if (opt$new_only) e[e$is_new, , drop = FALSE] else e

# One part of a section: its entries and the layout that draws them.
#   list   references: a hanging indent, each entry kept whole on one page
#   rows   a date (or other short label) at the left, text at the right,
#          optionally gathered under a bold `group`
#   tree   nested bullets: a bold `category`, then items, then groups of items
#   table  a real table; every column but is_new/new_date/tag is shown, and
#          `tag` says which rows to flag in a review copy. A short table is
#          kept on one page (`keep`); a long one breaks and repeats its header.
cv_part = function(layout, e, subtitle = NULL, align = NULL, widths = NULL, keep = FALSE)
  list(layout = layout, e = e, subtitle = subtitle, align = align, widths = widths, keep = keep)

# A heading, an optional note, and the parts that have anything to show. A
# part with nothing left (after the "only what is new" filter) disappears, and
# a section with no parts disappears with them.
emit_section = function(title, opt, ..., note = NULL, new_page = FALSE) {
  parts = Filter(function(p) !is.null(p) && nrow(apply_view(p$e, opt)) > 0, list(...))
  if (!length(parts)) return(invisible(FALSE))
  if (new_page) cat("\n\n{{< pagebreak >}}\n")
  cv_heading(title)
  if (!is.null(note)) cat(note, "\n\n", sep = "")
  for (p in parts) {
    e = apply_view(p$e, opt)
    if (!is.null(p$subtitle)) cat("### ", p$subtitle, "\n\n", sep = "")
    switch(p$layout,
           list  = write_list(e, opt),
           rows  = write_rows(e, opt),
           tree  = write_tree(e, opt),
           table = write_table(e, opt, p$align, p$widths, p$keep))
  }
  invisible(TRUE)
}

emit_list = function(e, title, opt, subtitle = NULL, note = NULL)
  emit_section(title, opt, cv_part("list", e, subtitle), note = note)
emit_rows = function(e, title, opt, subtitle = NULL)
  emit_section(title, opt, cv_part("rows", e, subtitle))

# Hanging indent, spacing and keeping each entry on one page come from the
# format-specific styling of `.cv-list`.
write_list = function(e, opt) {
  cat("::: {.cv-list custom-style=\"CV Entry\"}\n\n")
  for (i in seq_len(nrow(e)))
    cat(new_tag(opt, e$is_new[i]), e$body[i], "\n\n", sep = "")
  cat(":::\n\n")
}

# Written as a Markdown definition list; `cv.lua` turns it into a borderless
# two-column table, which every output format draws natively.
write_rows = function(e, opt) {
  groups = if ("group" %in% names(e)) unique(e$group) else NA
  for (g in groups) {
    d = if (is.na(g)) e else e[!is.na(e$group) & e$group == g, , drop = FALSE]
    # the group's label and its rows travel together
    cat("::: {.cv-group}\n\n")
    if (!is.na(g)) cat("::: {custom-style=\"CV Group\"}\n**", g, "**\n:::\n\n", sep = "")
    cat("::: {.cv-rows}\n\n")
    for (i in seq_len(nrow(d)))
      cat(d$label[i], "\n:   ", new_tag(opt, d$is_new[i]),
          gsub("\n", "\n    ", d$body[i]), "\n\n", sep = "")
    cat(":::\n\n:::\n\n")
  }
}

write_tree = function(e, opt) {
  cat("::: {.cv-tree}\n\n")
  for (cat_name in unique(e$category)) {
    d = e[e$category == cat_name, , drop = FALSE]
    cat("::: {custom-style=\"CV Group\"}\n**", cat_name, "**\n:::\n\n", sep = "")
    item = function(i, indent)
      cat(indent, "- ", new_tag(opt, d$is_new[i]), d$body[i], "\n", sep = "")
    for (i in which(is.na(d$group))) item(i, "")
    for (g in unique(d$group[!is.na(d$group)])) {
      cat("- ", g, "\n", sep = "")
      for (i in which(!is.na(d$group) & d$group == g)) item(i, "    ")
    }
    cat("\n")
  }
  cat(":::\n\n")
}

# A Markdown pipe table. Pandoc reads the dashes of the separator row as
# relative column widths whenever a row is long enough to need wrapping.
write_table = function(e, opt, align = NULL, widths = NULL, keep = FALSE) {
  cols = setdiff(names(e), c("is_new", "new_date", "tag"))
  align  = align  %||% rep("l", length(cols))
  widths = widths %||% rep(1, length(cols))
  cells = lapply(e[cols], function(x) ifelse(is.na(x), "", as.character(x)))
  if ("tag" %in% names(e))
    cells[[1]] = paste0(vapply(e$tag, function(t) new_tag(opt, t), character(1)), cells[[1]])
  n = pmax(4, round(60 * widths / sum(widths)))
  rule = ifelse(align == "r", paste0(strrep("-", n - 1), ":"), paste0(":", strrep("-", n - 1)))
  row = function(x) paste0("| ", paste(x, collapse = " | "), " |\n")
  cat(if (keep) "::: {.cv-table .cv-keep}" else "::: {.cv-table}", "\n\n",
      row(md_escape(cols)), row(rule), sep = "")
  for (i in seq_len(nrow(e))) cat(row(vapply(cells, `[`, character(1), i)))
  cat("\n:::\n\n")
}
