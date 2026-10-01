# Shared rules for reading and presenting the CV data.
#
# Sourced by JaradNiemi-CV.Rnw (LaTeX) and by the website (HTML), so the two
# cannot disagree about who is an advisee, how a name matches a byline, or how
# a partial date is shown. Nothing here knows about an output format: callers
# pass in their own escaping and emphasis. Base R only, so the website build
# does not need the tidyverse.

# a CSV from data/ as plain character data, blanks as NA
cv_read = function(name, dir = ".") {
  read.csv(file.path(dir, "data", paste0(name, ".csv")),
           na.strings = "", check.names = FALSE,
           stringsAsFactors = FALSE, encoding = "UTF-8")
}

# every way a person's name may appear in a byline, longest first so that
# "Jarad B. Niemi" is tried before "Jarad Niemi"
cv_spellings = function(people, aliases) {
  s = rbind(data.frame(person_id = people$person_id,  spelling = people$name),
            data.frame(person_id = aliases$person_id, spelling = aliases$alias))
  s[order(-nchar(s$spelling)), ]
}

# chair or co-chair both count as having advised the student
cv_advisee_ids = function(committees) {
  unique(committees$person_id[!is.na(committees$Chair)])
}

# escape regex metacharacters one at a time; a character class trips over {}
rx_escape = function(s) {
  for (ch in c("\\", ".", "|", "(", ")", "[", "]", "{", "}", "^", "$", "*", "+", "?"))
    s = gsub(ch, paste0("\\", ch), s, fixed=TRUE)
  s
}

# Mark my own name and my advisees in a byline. `escape` is the output
# format's escaping, applied to the byline and to each spelling before they
# are compared; `me` and `advisee` wrap a matched (escaped) name.
decorate_names = function(s, spellings, advisee_ids,
                          escape  = identity,
                          me      = function(x) x,
                          advisee = function(x) paste0(x, "*"),
                          me_id   = "jarad-niemi") {
  if (is.na(s)) return(s)
  out = escape(s)
  for (i in seq_len(nrow(spellings))) {
    pid = spellings$person_id[i]
    esc = escape(spellings$spelling[i])
    if (!grepl(esc, out, fixed=TRUE)) next
    rep = if (pid == me_id)             me(esc)
          else if (pid %in% advisee_ids) advisee(esc)
          else next
    # a spelling only counts at an author boundary, so "J. Niemi" does not
    # match inside "Gerald J. Niemi"
    pat = paste0("(^|,\\s*|\\s+and\\s+|\\(\\s*)", rx_escape(esc), "(?=$|[,.;)]|\\s)")
    out = gsub(pat, paste0("\\1", gsub("\\\\", "\\\\\\\\", rep)), out, perl=TRUE)
  }
  out
}

# partial ISO 8601 ("2020", "2020-10") -> earliest instant it could denote
iso_floor = function(x) as.Date(ifelse(is.na(x), NA_character_,
  ifelse(grepl("^\\d{4}$", x),        paste0(x,"-01-01"),
  ifelse(grepl("^\\d{4}-\\d{2}$", x), paste0(x,"-01"), x))))

# ISO 8601 at whatever precision was recorded -> "2024", "June 2024", "5 Jun 2024"
fmt_date = function(d) {
  if (is.na(d)) return("")
  if (nchar(d) == 4) return(d)
  if (nchar(d) == 7) return(format(as.Date(paste0(d, "-01")), "%B %Y"))
  sub("^0", "", format(as.Date(d), "%d %b %Y"))
}

# 2018 | AY18-19 | 2011--2022 | 2020--present
# a span of two consecutive years is an academic year, which is how committee
# and departmental terms are actually counted; `dash` is the output format's
# en dash
span = function(s, e, academic = TRUE, dash = "--") {
  s = as.integer(substr(s, 1, 4)); e = as.integer(substr(e, 1, 4))
  mapply(function(s1, e1) {
    if (is.na(s1))        return(NA_character_)
    if (is.na(e1))        return(paste0(s1, dash, "present"))
    if (e1 == s1)         return(as.character(s1))
    if (academic && e1 == s1 + 1) return(sprintf("AY%02d-%02d", s1 %% 100, e1 %% 100))
    paste0(s1, dash, e1)
  }, s, e)
}

# "A", "A and B", "A, B, and C"
name_list = function(v) {
  v = v[!is.na(v) & v != ""]
  if (length(v) <= 1) return(paste(v, collapse=""))
  if (length(v) == 2) return(paste(v, collapse=" and "))
  paste0(paste(v[-length(v)], collapse=", "), ", and ", v[length(v)])
}
