#!/usr/bin/env python3
"""Import a curated Markdown directory into catalog/armory.tsv.

Usage: python3 tools/import_md.py SOURCE.md > catalog/armory.tsv
Reads '- [Name](url) — desc' bullets and '| [Name](url) | desc |' rows
under numbered '# N. Title' sections. First category wins for duplicates.
"""
import re, sys

SLUGS = {1: "essentials", 2: "design", 3: "engineering", 4: "copywriting",
         5: "social", 6: "youtube", 7: "motion", 8: "image", 9: "audio",
         10: "fiction", 11: "editing", 12: "research", 13: "security",
         14: "automation", 15: "docs", 16: "data", 17: "product", 22: "collections"}
LINK = re.compile(r"^(?:-|\|)\s*\[([^\]]+)\]\((https://github\.com/[^)\s]+)\)\s*(?:—|-|\|)?\s*(.*)$")

def clean(s):
    s = re.sub(r"\s*\|\s*$", "", s).replace("\t", " ").strip()
    return re.sub(r"\s+", " ", s)

def kind(name, url, desc):
    t = f"{name} {url} {desc}".lower()
    if "collection" in t or "awesome" in t or "catalog" in t: return "collection"
    if "skill" in t or "agent instruction" in t: return "skill"
    if "mcp" in t: return "mcp"
    return "tool"

section, seen = None, {}
for line in open(sys.argv[1], encoding="utf-8"):
    m = re.match(r"^# (\d+)\. ", line)
    if m: section = int(m.group(1)); continue
    if section not in SLUGS: continue
    m = LINK.match(line.strip())
    if not m: continue
    name, url, desc = m.group(1).strip(), m.group(2).rstrip("/."), clean(m.group(3))
    key = url.lower()
    if key in seen:
        if not seen[key][4] and desc: seen[key][4] = desc
        continue
    slug = re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")
    seen[key] = [slug, SLUGS[section], kind(name, url, desc), name, desc, url]

ids = set()
print("# id\tcategory\tkind\tname\tdescription\turl")
for row in seen.values():
    base, n = row[0], 2
    while row[0] in ids: row[0] = f"{base}-{n}"; n += 1
    ids.add(row[0])
    if not row[4]: row[4] = "No description yet."
    print("\t".join(row))
