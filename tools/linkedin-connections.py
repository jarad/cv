"""Update students' LinkedIn profiles and current positions from a LinkedIn
connections export.

    python3 tools/linkedin-connections.py Connections.csv            # show changes
    python3 tools/linkedin-connections.py Connections.csv --write    # apply them

Connections.csv comes from LinkedIn: Settings & Privacy > Data privacy > Get a
copy of your data > Connections. It lists every connection, not only students,
so keep it out of the repository (.gitignore covers it).

Only students (people in data/studentcommittees.csv) are considered. A
connection is matched to a student, strongest first, by

  url    the LinkedIn profile already recorded for the student
  name   the full name, or an alias from data/aliases.csv
  short  first and last name only (middle names and initials dropped)

ignoring case, accents, punctuation and credentials such as ", PhD". A name
that fits more than one student, or more than one connection, is reported and
left alone. So is a connection whose profile differs from the one already
recorded: it may be a namesake.

For a match, `linkedin`, `current_title` and `current_affiliation` are set from
the export (an empty Company or Position leaves the recorded value), and
`profiles_checked` is set to today, or to --date. Nothing is written without
--write; read the changes first, since a name-only match among your
connections can still be the wrong person.

Last, every student still without a profile is listed with the unmatched
connections whose name nearly fits (a nickname, reversed name order, a changed
or misspelled last name). Confirming one means adding that spelling to
data/aliases.csv; the next run then matches it by name.
"""
import argparse
import csv
import datetime
import io
import re
import sys
import unicodedata
from collections import defaultdict
from difflib import SequenceMatcher

CREDENTIALS = {"phd", "ph d", "ms", "msc", "ma", "mba", "mph", "md", "pe", "cpa", "pmp", "pstat", "jr", "sr"}


def norm(s):
    """Lowercase ASCII words: 'Domínguez-Lorenzo, PhD' -> 'dominguez lorenzo'."""
    s = unicodedata.normalize("NFKD", s or "").encode("ascii", "ignore").decode()
    s = s.split(",")[0]                          # drop ", PhD", ", MS, PStat" and the like
    s = re.sub(r"\(.*?\)", " ", s)               # nicknames in parentheses
    words = re.sub(r"[^a-z]+", " ", s.lower()).split()
    return " ".join(w for w in words if w not in CREDENTIALS)


def short(name):
    """First and last word only: 'jarad b niemi' -> 'jarad niemi'."""
    w = name.split()
    return f"{w[0]} {w[-1]}" if len(w) > 1 else name


def near_miss(student_names, conn_name):
    """How closely a connection's name fits a student who did not match, and why.

    Returns (score, reason), or (0, "") when it is not worth showing. The names
    are already normalized; a student may have several (name and aliases).
    """
    cw = conn_name.split()
    if len(cw) < 2:
        return 0, ""
    best = (0, "")
    for s in student_names:
        sw = s.split()
        if len(sw) < 2:
            continue
        first = SequenceMatcher(None, sw[0], cw[0]).ratio()
        last = SequenceMatcher(None, sw[-1], cw[-1]).ratio()
        if sw[0] == cw[-1] and sw[-1] == cw[0]:
            hit = (0.95, "name order reversed")
        elif sw[-1] == cw[-1] and (sw[0][0] == cw[0][0] or first >= 0.5):
            hit = (0.6 + 0.4 * first, "same last name")
        elif sw[0] == cw[0] and sw[-1] in cw[1:]:
            hit = (0.8, "last name within a longer one")
        elif sw[0] == cw[0] and last >= 0.75:
            hit = (0.5 + 0.4 * last, "similar last name")
        elif SequenceMatcher(None, s, conn_name).ratio() >= 0.85:
            hit = (0.5, "similar spelling")
        else:
            continue
        best = max(best, hit)
    return best


def profile_url(u):
    """https://www.linkedin.com/in/<slug>/ regardless of subdomain, query or slash."""
    m = re.search(r"linkedin\.com/in/([^/?#]+)", u or "")
    return f"https://www.linkedin.com/in/{m.group(1).lower()}/" if m else ""


def read_connections(path):
    # the export opens with a few lines of notes before the header row
    text = open(path, encoding="utf-8-sig").read()
    lines = text.splitlines(keepends=True)
    start = next((i for i, l in enumerate(lines) if l.startswith("First Name")), None)
    if start is None:
        sys.exit(f"{path}: no 'First Name,Last Name,...' header row found")
    return list(csv.DictReader(io.StringIO("".join(lines[start:]))))


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("connections", help="Connections.csv from the LinkedIn data export")
    ap.add_argument("--write", action="store_true", help="apply the changes to people.csv")
    ap.add_argument("--date", default=datetime.date.today().isoformat(),
                    help="date for profiles_checked (default: today)")
    ap.add_argument("--data", default="data", help="directory holding the CSVs")
    a = ap.parse_args()

    people_path = f"{a.data}/people.csv"
    people = list(csv.DictReader(open(people_path, newline="", encoding="utf-8")))
    cols = list(people[0].keys())
    students = {r["person_id"] for r in csv.DictReader(open(f"{a.data}/studentcommittees.csv", encoding="utf-8"))}
    aliases = defaultdict(list)
    for r in csv.DictReader(open(f"{a.data}/aliases.csv", encoding="utf-8")):
        aliases[r["person_id"]].append(r["alias"])
    conns = read_connections(a.connections)

    # every key that can identify a student, and which students it points to
    by_url, by_name, by_short = defaultdict(set), defaultdict(set), defaultdict(set)
    for p in people:
        pid = p["person_id"]
        if pid not in students:
            continue
        if p["linkedin"]:
            by_url[profile_url(p["linkedin"])].add(pid)
        for n in [p["name"]] + aliases[pid]:
            by_name[norm(n)].add(pid)
            by_short[short(norm(n))].add(pid)

    # connection name keys, to spot two connections sharing a student's name
    conn_names = defaultdict(int)
    for c in conns:
        conn_names[short(norm(f"{c['First Name']} {c['Last Name']}"))] += 1

    matched, ambiguous = {}, []
    for c in conns:
        full = norm(f"{c['First Name']} {c['Last Name']}")
        url = profile_url(c.get("URL", ""))
        for kind, hits in (("url", by_url.get(url, set())),
                           ("name", by_name.get(full, set())),
                           ("short", by_short.get(short(full), set()))):
            if not hits:
                continue
            if len(hits) > 1 or (kind != "url" and conn_names[short(full)] > 1):
                ambiguous.append(f"{c['First Name']} {c['Last Name']}: {kind} match fits "
                                 f"{len(hits)} student(s) and {conn_names[short(full)]} connection(s)")
            else:
                pid = next(iter(hits))
                if pid in matched:
                    ambiguous.append(f"{pid}: matched by more than one connection")
                    matched[pid] = None
                else:
                    matched[pid] = (kind, c, url)
            break

    changes, conflicts = [], []
    by_id = {p["person_id"]: p for p in people}
    for pid, m in sorted(matched.items()):
        if m is None:
            continue
        kind, c, url = m
        p = by_id[pid]
        if p["linkedin"] and url and profile_url(p["linkedin"]) != url:
            conflicts.append(f"{pid}: recorded {p['linkedin']}, connection {url} ({kind} match)")
            continue
        new = {"linkedin": url or p["linkedin"],
               "current_title": c.get("Position", "").strip() or p["current_title"],
               "current_affiliation": c.get("Company", "").strip() or p["current_affiliation"],
               "profiles_checked": a.date}
        diff = {k: (p[k], v) for k, v in new.items() if p[k] != v}
        changes.append((pid, kind, diff))
        p.update(new)

    print(f"{len(conns)} connections, {len(students)} students, {len(changes)} matched\n")
    for pid, kind, diff in changes:
        shown = {k: d for k, d in diff.items() if k != "profiles_checked"}
        print(f"{pid}  [{kind}]" + ("" if shown else "  unchanged"))
        for k, (old, new) in shown.items():
            print(f"    {k}: {old or '-'}  ->  {new}")
    for title, items in (("Not applied: a different profile is already recorded", conflicts),
                         ("Not applied: ambiguous", ambiguous)):
        if items:
            print(f"\n{title}")
            for s in dict.fromkeys(items):
                print("    " + s)

    # Students still without a profile, and connections whose name nearly fits:
    # a nickname, a reversed name order, a changed or misspelled last name.
    used = {m[2] for m in matched.values() if m}
    spare = [c for c in conns if profile_url(c.get("URL", "")) not in used]
    missing, none_close = [], []
    for pid in sorted(students):
        p = by_id[pid]
        if p["linkedin"]:
            continue
        names = {norm(n) for n in [p["name"]] + aliases[pid]}
        cands = sorted(((score, why, c) for c in spare
                        for score, why in [near_miss(names, norm(f"{c['First Name']} {c['Last Name']}"))]
                        if score), key=lambda x: -x[0])[:3]
        (missing if cands else none_close).append((p, cands))
    if missing:
        print("\nStill without a LinkedIn profile, with connections whose name nearly fits.\n"
              "To accept one, add its spelling to data/aliases.csv (person_id,alias) and rerun:")
        for p, cands in missing:
            print(f"    {p['person_id']} ({p['name']})")
            for _, why, c in cands:
                print(f"        {c['First Name']} {c['Last Name']}  [{why}]  "
                      f"{c.get('Company', '') or '-'}, {c.get('Position', '') or '-'}  {profile_url(c.get('URL', ''))}")
    if none_close:
        print(f"\nStill without a LinkedIn profile, no connection close by name ({len(none_close)}), "
              "probably not connected:\n    " + ", ".join(p["name"] for p, _ in none_close))

    if a.write:
        out = io.StringIO()
        w = csv.DictWriter(out, fieldnames=cols, lineterminator="\n")
        w.writeheader()
        w.writerows(people)
        open(people_path, "w", newline="", encoding="utf-8").write(out.getvalue())
        print(f"\nwrote {people_path}")
    else:
        print("\nnothing written; rerun with --write to apply")


if __name__ == "__main__":
    main()
