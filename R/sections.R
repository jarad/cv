# Each function reads one or more CSVs and returns entries in the shape
# described at the top of cv.R. None of them knows what format it is
# being rendered to, or whether the reader wants everything or only what is new.
#
# Prototype: Education, Positions, Journal articles and Talks. The rest of the
# CV still lives in JaradNiemi-CV.Rnw until it is ported.

source("R/cv.R")

sec_education = function(opt, dir = "data") {
  ed = read_csv(file.path(dir, "education.csv"), show_col_types = FALSE) |>
    arrange(desc(year))
  body = vapply(seq_len(nrow(ed)), function(i) {
    d = ed[i, ]
    paste(c(paste0("**", md_text(d$degree), "** ", md_text(d$field), ", ", md_text(d$institution)),
            if (!is.na(d$thesis))  paste0("Thesis: ",  md_text(d$thesis)),
            if (!is.na(d$advisor)) paste0("Advisor: ", md_text(d$advisor))),
          collapse = "\\\n")
  }, character(1))
  tibble(label = as.character(ed$year), body = body, new_date = as.character(ed$year),
         is_new = is_new(ed$year, opt$since))
}

# Appointments are gathered under the unit they were held in, newest first.
sec_positions = function(opt, dir = "data") {
  pos = read_csv(file.path(dir, "positions.csv"), show_col_types = FALSE,
                 col_types = cols(.default = col_character()))
  pos = pos[order(-as.integer(substr(pos$start_date, 1, 4))), ]
  tibble(group    = paste0(md_text(pos$unit), ", ", md_text(pos$institution)),
         label    = span(pos$start_date, pos$end_date, academic = FALSE),
         body     = md_text(pos$title),
         new_date = pos$start_date,
         is_new   = is_new(pos$start_date, opt$since))
}

# What counts as new: acceptance, else first appearance (online or in print),
# else the year. Acceptance dates are not recorded yet, so for now the
# fallback does the work; fill in `date_accepted` and it takes over.
pub_new_date = function(p) {
  first_public = pmin(iso_ceil(p$date_online), iso_ceil(p$date_print), na.rm = TRUE)
  as.character(dplyr::coalesce(iso_ceil(p$date_accepted), first_public,
                               iso_ceil(as.character(p$year))))
}

sec_articles = function(opt, dir = "data") {
  ppl  = load_people(dir)
  pubs = read_csv(file.path(dir, "publications.csv"), show_col_types = FALSE,
                  col_types = cols(.default = col_character())) |>
    filter(status == "published", type == "journal article") |>
    arrange(desc(as.integer(year)))
  body = vapply(seq_len(nrow(pubs)), function(i) {
    d = pubs[i, ]
    in_print = !is.na(d$volume)
    end = ""
    if (in_print) end = paste0("**", md_text(d$volume), "**")
    if (!is.na(d$issue))  end = paste0(end, "(", md_text(d$issue), ")")
    if (!is.na(d$number)) end = paste0(end, ":", md_text(d$number))
    if (!is.na(d$pages))  end = paste0(end, ", ", md_text(d$pages))
    if (in_print)         end = paste0(end, ". ")
    paste0(decorate_authors(d$authors, ppl), ". (", d$year, ") ", md_text(d$title), " ",
           if (in_print) paste0("*", md_text(d$journal), "*, ")
           else          paste0("*to appear in ", md_text(d$journal), "* "),
           end,
           if (!is.na(d$url)) paste0("[url](<", d$url, ">)") else "")
  }, character(1))
  nd = pub_new_date(pubs)
  tibble(body = trimws(body), new_date = nd, is_new = is_new(nd, opt$since))
}

fmt_date = function(d) {
  if (is.na(d)) return("")
  if (nchar(d) == 4) return(d)
  if (nchar(d) == 7) return(format(as.Date(paste0(d, "-01")), "%B %Y"))
  sub("^0", "", format(as.Date(d), "%d %b %Y"))
}

sec_talks = function(opt, dir = "data") {
  pres = read_csv(file.path(dir, "presentations.csv"), show_col_types = FALSE,
                  col_types = cols(.default = col_character())) |>
    filter(kind == "talk") |>
    arrange(desc(coalesce(date, "0000")))
  body = vapply(seq_len(nrow(pres)), function(i) {
    d = pres[i, ]
    bits = c(if (!is.na(d$solicitation)) d$solicitation, if (!is.na(d$notes)) d$notes)
    paste0("“", md_text(d$title), ",” ", md_text(d$venue),
           if (!is.na(d$date)) paste0(", ", fmt_date(d$date)) else "",
           if (length(bits)) paste0(" (", md_text(paste(bits, collapse = "; ")), ")") else "")
  }, character(1))
  tibble(body = body, new_date = pres$date, is_new = is_new(pres$date, opt$since))
}
