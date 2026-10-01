# Each function reads one or more CSVs and returns entries in the shape
# described at the top of cv.R. None of them knows what format it is
# being rendered to, or whether the reader wants everything or only what is new.
#
# Every section of the CV is here. JaradNiemi-CV.Rnw is the LaTeX build of the
# same data and renders the same sections.

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

# ---- employment --------------------------------------------------------------

# Roles in the order they first appear, each role's jobs newest first.
sec_employment = function(opt, dir = "data") {
  emp = read_csv(file.path(dir, "employment.csv"), show_col_types = FALSE,
                 col_types = cols(.default = col_character()))
  emp = emp[order(match(emp$role, unique(emp$role)),
                  -as.integer(substr(emp$start_date, 1, 4))), ]
  who = md_text(emp$employer)
  sup = !is.na(emp$supervisor)
  who[sup] = paste0(who[sup], " (", md_text(emp$supervisor[sup]), ")")
  tibble(group = md_text(emp$role), label = span(emp$start_date, emp$end_date, academic = FALSE),
         body = who, new_date = emp$start_date, is_new = is_new(emp$start_date, opt$since))
}

# ---- publications that are not published journal articles --------------------

md_link = function(text, href) if (is.na(href)) text else paste0("[", text, "](<", href, ">)")

read_pubs = function(dir)
  read_csv(file.path(dir, "publications.csv"), show_col_types = FALSE,
           col_types = cols(.default = col_character()))

# Work that is not out yet, newest first: in preparation, under revision, or
# submitted. `include` is FALSE unless the reader asked for it.
sec_unpublished = function(opt, status, include, dir = "data") {
  ppl  = load_people(dir)
  want = status
  pubs = read_pubs(dir) |>
    filter(status == want, type == "journal article") |>
    arrange(desc(as.numeric(sort_order)))
  if (!include) pubs = pubs[0, ]
  how = c("in preparation" = "", "under revision" = " *under revision for %s*",
          "submitted" = " *submitted to %s*")[[want]]
  body = vapply(seq_len(nrow(pubs)), function(i) {
    d = pubs[i, ]
    paste0(decorate_authors(d$authors, ppl), ". ", md_text(d$title),
           if (nzchar(how)) sprintf(how, md_text(d$journal)),
           if (!is.na(d$`pre-print`)) paste0(" <", d$`pre-print`, ">"))
  }, character(1))
  nd = as.character(dplyr::coalesce(pubs$date_submitted, pubs$date_last_activity))
  tibble(body = body, new_date = nd, is_new = is_new(nd, opt$since))
}

# What follows the title: a URL is shown the way the LaTeX CV always has, as a
# "url" link, bare, or (for a patent) bare on its own line.
url_tail = function(kind, u) {
  if (is.na(u)) return("")
  switch(kind,
    "book review"        = paste0("[url](<", u, ">)"),
    "patent application" = paste0("\\\n<", u, ">"),
    "other manuscript"   = paste0("<", u, ">"),
    paste0("([url](<", u, ">))"))
}

# Book chapters, proceedings, abstracts, book reviews, patents and other
# manuscripts share one shape: authors. (year) title. details url
sec_other_pubs = function(opt, kind, dir = "data") {
  ppl  = load_people(dir)
  want = kind
  pubs = read_pubs(dir) |> filter(status == "published", type == want)
  nd   = pub_new_date(pubs)
  pubs = pubs[order(-as.numeric(iso_ceil(nd))), ]    # newest first, ties keep file order
  nd   = pub_new_date(pubs)
  body = vapply(seq_len(nrow(pubs)), function(i) {
    d = pubs[i, ]
    title = md_text(d$title)
    if (kind == "book review") title = paste0("[", title, "]{.underline}")
    trimws(paste0(decorate_authors(d$authors, ppl), ". ",
                  if (!is.na(d$year)) paste0("(", d$year, ") "),
                  title, ". ",
                  if (!is.na(d$details)) paste0(md_text(d$details), " "),
                  url_tail(kind, d$url)))
  }, character(1))
  tibble(body = body, new_date = nd, is_new = is_new(nd, opt$since))
}

# ---- posters, news ------------------------------------------------------------

# "A", "A and B", "A, B, and C"
name_list = function(v) {
  v = v[!is.na(v) & v != ""]
  if (length(v) <= 1) return(paste(v, collapse = ""))
  if (length(v) == 2) return(paste(v, collapse = " and "))
  paste0(paste(v[-length(v)], collapse = ", "), ", and ", v[length(v)])
}

sec_posters = function(opt, dir = "data") {
  ppl  = load_people(dir)
  pres = read_csv(file.path(dir, "presentations.csv"), show_col_types = FALSE,
                  col_types = cols(.default = col_character())) |>
    filter(kind == "poster") |>
    arrange(desc(coalesce(date, "0000")))
  body = vapply(seq_len(nrow(pres)), function(i) {
    d = pres[i, ]
    who = name_list(c(d$presenting_author,
                      if (!is.na(d$work_authors)) trimws(strsplit(d$work_authors, ",")[[1]])))
    # posters are always contributed, so the solicitation is left off
    paste0(decorate_authors(who, ppl), ". ", md_text(d$title), ".",
           if (!is.na(d$venue)) paste0(" ", md_text(d$venue)),
           if (!is.na(d$date)) paste0(", ", fmt_date(d$date)),
           if (!is.na(d$notes)) paste0(" (", md_text(d$notes), ")"))
  }, character(1))
  tibble(body = body, new_date = pres$date, is_new = is_new(pres$date, opt$since))
}

# One paragraph: an outlet that interviewed me several times has its years
# listed after it. A single paragraph cannot be partly new, so the "only what
# is new" view filters the interviews first and keeps what is left.
sec_news = function(opt, dir = "data") {
  nw = read_csv(file.path(dir, "news.csv"), show_col_types = FALSE,
                col_types = cols(.default = col_character()))
  if (opt$new_only) nw = nw[is_new(nw$year, opt$since), ]
  items = character(0)
  for (o in unique(nw$outlet)) {
    d = nw[nw$outlet == o, ]
    items = c(items, if (nrow(d) == 1) md_link(md_text(o), d$url[1]) else {
      d = d[order(d$year), ]
      paste0(md_text(o), " (", paste(mapply(md_link, d$year, d$url, USE.NAMES = FALSE),
                                     collapse = ", "), ")")
    })
  }
  if (!length(items)) return(tibble(body = character(0), is_new = logical(0)))
  tibble(body = paste(items, collapse = ",\n"), is_new = opt$new_only)
}

# ---- courses -------------------------------------------------------------------

# the month a term ends, so a course is "new" by its term rather than its year
TERM_END = c(Spring = 5, Summer = 8, Fall = 12, Winter = 12, setNames(1:12, month.abb))
TERM_ORDER = c(Spring = 1, Summer = 2, Fall = 3, Winter = 4, setNames(1:12, month.abb))

read_courses = function(kind, dir) {
  co = read_csv(file.path(dir, "courses.csv"), show_col_types = FALSE,
                col_types = cols(.default = col_character()))
  co = co[co$kind == kind, ]
  co[order(-as.integer(co$year), -TERM_ORDER[co$term]), ]
}

# Regular courses, gathered by institution; one row per term, its courses
# stacked at the right.
sec_regular_courses = function(opt, dir = "data") {
  co  = read_courses("regular", dir)
  key = paste(co$institution, co$term, co$year, sep = "\r")
  text = vapply(seq_len(nrow(co)), function(i)
    paste(md_text(c(co$number[i], co$title[i])[!is.na(c(co$number[i], co$title[i]))]),
          collapse = " "), character(1))
  first = !duplicated(key)
  nd = sprintf("%s-%02d", co$year, TERM_END[co$term])[first]
  tibble(group    = paste0("At ", md_text(co$institution[first]), ":"),
         label    = paste(co$term, co$year)[first],
         body     = vapply(key[first], function(k) paste(text[key == k], collapse = "\\\n"),
                           character(1), USE.NAMES = FALSE),
         new_date = nd, is_new = is_new(nd, opt$since))
}

sec_short_courses = function(opt, dir = "data") {
  co = read_courses("short", dir)
  nd = sprintf("%s-%02d", co$year, TERM_END[co$term])
  tibble(label = paste(co$term, co$year),
         body  = paste0(md_text(co$title),
                        ifelse(is.na(co$duration), "", paste0(" (", md_text(co$duration), ")")),
                        ", ", md_text(co$institution)),
         new_date = nd, is_new = is_new(nd, opt$since))
}

# ---- grants, honors, memberships -------------------------------------------------

# $1,088,156 and $746,204.44: thousands separators, cents only when present
money = function(a) {
  a = as.numeric(a)
  paste0("\\$", formatC(a, format = "f", digits = if (a == round(a)) 0 else 2, big.mark = ","))
}

sec_grants = function(opt, dir = "data") {
  g = read_csv(file.path(dir, "grants.csv"), show_col_types = FALSE,
               col_types = cols(.default = col_character()))
  g = g[order(g$start_date, decreasing = TRUE), ]
  body = vapply(seq_len(nrow(g)), function(i) {
    d = g[i, ]
    paste0(md_text(d$funder),
           if (!is.na(d$award_number)) paste0(" (\\#", md_text(d$award_number), ")"),
           ", ", md_text(d$title), ",",
           if (!is.na(d$role)) paste0(" Role: ", md_text(d$role), ","),
           " ", fmt_date(d$start_date), " to ", fmt_date(d$end_date),
           if (!is.na(d$amount_total))
             paste0(" [", money(d$amount_total),
                    if (!is.na(d$amount_niemi)) paste0("; ", money(d$amount_niemi), " to Niemi"), "]"),
           if (!is.na(d$notes)) paste0(" (", md_text(d$notes), ")"))
  }, character(1))
  tibble(body = body, new_date = g$start_date, is_new = is_new(g$start_date, opt$since))
}

sec_honors = function(opt, dir = "data") {
  h = read_csv(file.path(dir, "honors.csv"), show_col_types = FALSE,
               col_types = cols(.default = col_character()))
  h = h[order(h$start_date, decreasing = TRUE), ]
  body = vapply(seq_len(nrow(h)), function(i) {
    d = h[i, ]
    label = md_text(d$name)
    if (!is.na(d$organization)) label = paste0(md_text(d$organization), " ", label)
    paste0(md_link(label, d$url),
           if (!is.na(d$notes)) paste0(" (", md_link(md_text(d$notes), d$notes_url), ")"),
           if (!is.na(d$amount))
             paste0(" [\\$", formatC(as.numeric(d$amount), format = "d", big.mark = ","), "]"),
           if (!is.na(d$start_date)) paste0(" (", span(d$start_date, d$end_date), ")"))
  }, character(1))
  tibble(body = body, new_date = h$start_date, is_new = is_new(h$start_date, opt$since))
}

# Memberships carry no dates today, so none is ever "new".
sec_memberships = function(opt, dir = "data") {
  m = read_csv(file.path(dir, "memberships.csv"), show_col_types = FALSE,
               col_types = cols(.default = col_character()))
  tibble(body = md_text(m$organization), new_date = m$start_date,
         is_new = is_new(m$start_date, opt$since))
}

# ---- service -------------------------------------------------------------------

# One line for an activity held in one or more roles over one or more spans:
# "Faculty Search Committee, member (AY25-26, AY21-22), chair (AY23-24)".
service_item = function(d, opt) {
  d = d[order(-as.integer(substr(d$start_date, 1, 4))), ]
  org = d$organization[1]; act = d$activity[1]
  label = if (is.na(act)) org
          else if (is.na(org) || identical(org, d$group[1])) act
          else paste0(act, ", ", org)
  label = md_link(md_text(label), d$url[1])
  parts = character(0)
  roles = c(if (any(is.na(d$role))) NA_character_, unique(d$role[!is.na(d$role)]))
  for (r in roles) {
    k = if (is.na(r)) is.na(d$role) else (!is.na(d$role) & d$role == r)
    k = k & !is.na(d$start_date)
    if (!any(k)) next
    yrs = paste(span(d$start_date[k], d$end_date[k]), collapse = ", ")
    parts = c(parts, if (is.na(r)) paste0("(", yrs, ")") else paste0(md_text(r), " (", yrs, ")"))
  }
  sep = if (!length(parts)) "" else if (startsWith(parts[1], "(")) " " else ", "
  list(body = paste0(label, sep, paste(parts, collapse = ", ")),
       is_new = any(is_new(d$start_date, opt$since)))
}

# Three categories; in each, items that belong to no group come first and then
# each group's items, newest first.
sec_service = function(opt, dir = "data") {
  sv = read_csv(file.path(dir, "service.csv"), show_col_types = FALSE,
                col_types = cols(.default = col_character()))
  out = list()
  for (cat_name in c("Profession", "University service", "Departmental/Program service")) {
    dd = sv[sv$category == cat_name, ]
    for (g in c(NA, unique(dd$group[!is.na(dd$group)]))) {
      d = if (is.na(g)) dd[is.na(dd$group), ] else dd[!is.na(dd$group) & dd$group == g, ]
      d = d[order(-as.integer(substr(d$start_date, 1, 4))), ]
      key = paste(coalesce(d$organization, ""), coalesce(d$activity, ""), sep = "\r")
      for (k in unique(key)) {
        it = service_item(d[key == k, ], opt)
        out[[length(out) + 1]] = tibble(category = cat_name,
          group = if (is.na(g)) NA_character_ else md_text(g), body = it$body, is_new = it$is_new)
      }
    }
  }
  bind_rows(out)
}

# ---- students ------------------------------------------------------------------

# Every committee served on, with names resolved. A committee is new if it
# began, or its student graduated, on or after `since`.
committee_data = function(opt, dir = "data") {
  people = read_csv(file.path(dir, "people.csv"), show_col_types = FALSE)
  d = read_csv(file.path(dir, "studentcommittees.csv"), show_col_types = FALSE,
               col_types = cols(.default = col_character()))
  # a person missing from people.csv would silently vanish from the CV
  unresolved = setdiff(na.omit(c(d$person_id, d$co_chair_id)), people$person_id)
  if (length(unresolved))
    stop("person_id not found in people.csv: ", paste(unresolved, collapse = ", "))
  d = d |>
    left_join(people |> select(person_id, Student = name), by = "person_id") |>
    left_join(people |> select(co_chair_id = person_id, `Co-chair` = name), by = "co_chair_id") |>
    mutate(# master's degrees are reported together, whether the school awards an MS or an MA
           Degree = ifelse(Degree == "MA", "MS", Degree),
           Completed = ifelse(is.na(graduation_date), "In progress", substr(graduation_date, 1, 4)),
           is_new = is_new(start_date, opt$since) | is_new(graduation_date, opt$since),
           School = factor(School, levels = c("ISU", "UCSB")),
           Chair  = factor(Chair, levels = c("Chair", "Co-chair", "")))
  levels = unique(d$Department)
  d$Department = factor(d$Department, levels = c("STAT", setdiff(levels, "STAT")))
  d |> arrange(School, desc(Completed), Degree, Chair, Department)
}

sec_advisees = function(opt, dir = "data") {
  d = committee_data(opt, dir) |>
    filter(Chair %in% c("Chair", "Co-chair")) |>
    arrange(School, Degree, desc(Completed), Chair)
  tibble(Student = md_text(d$Student), School = as.character(d$School),
         Department = md_text(d$Department), Degree = d$Degree, Completed = d$Completed,
         Chair = as.character(d$Chair), `Co-chair` = md_text(d$`Co-chair`),
         is_new = d$is_new, tag = d$is_new)
}

# How many committees, by whether I chaired, whether the department is a
# statistics one, the degree, and whether the student has finished.
sec_committee_summary = function(opt, dir = "data") {
  d = committee_data(opt, dir)
  if (opt$new_only) d = d[d$is_new, ]
  s = d |>
    mutate(`Chair/Co-chair` = ifelse(Chair %in% c("Chair", "Co-chair"), "Yes", "No"),
           STAT = ifelse(Department %in% c("STAT", "PSTAT", "STAT&ECON"), "Yes", "No"),
           prog = factor(ifelse(Completed == "In progress", "In progress", "Completed"),
                         levels = c("Completed", "In progress"))) |>
    count(Degree, `Chair/Co-chair`, STAT, prog, .drop = FALSE) |>
    tidyr::pivot_wider(names_from = prog, values_from = n) |>
    filter(Completed + `In progress` > 0) |>
    arrange(desc(`Chair/Co-chair`), STAT, Degree) |>
    select(`Chair/Co-chair`, STAT, Degree, Completed, `In progress`)
  s[] = lapply(s, as.character)
  # a summary has no single date to flag
  s$is_new = rep(TRUE, nrow(s)); s$tag = rep(FALSE, nrow(s))
  s
}

sec_undergraduate_research = function(opt, dir = "data") {
  u = read_csv(file.path(dir, "undergraduate_research.csv"), show_col_types = FALSE,
               col_types = cols(.default = col_character()))
  nw = is_new(u$start_date, opt$since) | is_new(u$end_date, opt$since)
  tibble(Student = md_text(u$Student), Year = span(u$start_date, u$end_date, academic = FALSE),
         Topic = md_text(u$Topic), is_new = nw, tag = nw)
}

# Mentoring sits with the advisees rather than under service: it is work with
# individual students, not committee work.
sec_mentoring = function(opt, dir = "data") {
  m = read_csv(file.path(dir, "mentoring.csv"), show_col_types = FALSE,
               col_types = cols(.default = col_character()))
  m = m[order(m$start_date, decreasing = TRUE), ]
  nw = is_new(m$start_date, opt$since) | is_new(m$end_date, opt$since)
  tibble(Student = md_text(m$student), Program = md_text(m$programme),
         Institution = md_text(m$institution), Years = span(m$start_date, m$end_date),
         is_new = nw, tag = nw)
}
