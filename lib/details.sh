# details.sh - show what a skill or tool is, from its project page: summary, sections, pictures, videos.
# The README comes from the installed copy when there is one, otherwise it is fetched from the
# repository host and cached in $AR_DATA/cache. Everything printed is stripped of control characters,
# because README text is written by strangers.

AR_CACHE="$AR_DATA/cache"

# ar_repo_parts url -> "host<TAB>owner<TAB>repo<TAB>subfolder"
ar_repo_parts() {
  local split base sub rest host owner repo
  split="$(ar_split_url "$1")"; base="${split%%$'\t'*}"; sub="${split#*$'\t'}"
  rest="${base#https://}"; host="${rest%%/*}"; rest="${rest#*/}"
  owner="${rest%%/*}"; repo="${rest#*/}"; repo="${repo%%/*}"
  printf '%s\t%s\t%s\t%s\n' "$host" "$owner" "$repo" "$sub"
}

# Base URL for raw files on the default branch (HEAD), or empty if the host is unknown.
ar_raw_base() {
  local host owner repo sub
  IFS=$'\t' read -r host owner repo sub <<< "$(ar_repo_parts "$1")"
  case "$host" in
    github.com)   printf 'https://raw.githubusercontent.com/%s/%s/HEAD' "$owner" "$repo" ;;
    gitlab.com)   printf 'https://gitlab.com/%s/%s/-/raw/HEAD' "$owner" "$repo" ;;
    codeberg.org) printf 'https://codeberg.org/%s/%s/raw/branch/main' "$owner" "$repo" ;;
  esac
  [ -n "$sub" ] && printf '/%s' "$sub"
  return 0
}

# Print the path of a README for this entry (installed copy first, then a cached download).
ar_readme_file() {
  local id="$1" url="$2" sub dir f raw name
  sub="$(ar_repo_parts "$url" | cut -f4)"
  dir="$AR_REPOS/$id"; [ -n "$sub" ] && dir="$dir/$sub"
  for f in README.md readme.md Readme.md README.MD README.markdown README.rst README.txt README; do
    [ -f "$dir/$f" ] && { printf '%s' "$dir/$f"; return 0; }
  done
  mkdir -p "$AR_CACHE" || return 1
  f="$AR_CACHE/$id.readme"
  # Re-use a download for a day.
  if [ -s "$f" ] && [ -z "$(find "$f" -mtime +1 2>/dev/null)" ]; then printf '%s' "$f"; return 0; fi
  ar_have curl || return 1
  raw="$(ar_raw_base "$url")"; [ -n "$raw" ] || return 1
  for name in README.md readme.md Readme.md README.rst README; do
    if curl -fsSL --proto '=https' --max-time 15 --max-filesize 2000000 "$raw/$name" -o "$f.tmp" 2>/dev/null && [ -s "$f.tmp" ]; then
      mv "$f.tmp" "$f"; printf '%s' "$f"; return 0
    fi
  done
  rm -f "$f.tmp"
  return 1
}

# Parse a README into sections: SUMMARY lines, HEAD lines, IMG urls, VID urls (tab-separated tags).
ar_readme_parse() {
  python3 -I - "$1" "$2" <<'PY' 2>/dev/null
import re, sys, html
path, raw_base = sys.argv[1], sys.argv[2]
text = open(path, encoding="utf-8", errors="replace").read()[:400000]

def clean(s):
    s = re.sub(r"[\x00-\x08\x0b-\x1f\x7f​-‏‪-‮⁦-⁩]", "", s)  # no escapes
    return s.strip()

def absolute(u):
    u = u.strip().strip("<>").split()[0] if u.strip() else ""
    if not u or u.startswith(("data:", "#", "mailto:")):
        return ""
    if u.startswith("//"):
        u = "https:" + u
    if u.startswith("http://"):
        return ""
    if not u.startswith("https://"):
        if not raw_base:
            return ""
        u = raw_base.rstrip("/") + "/" + u.lstrip("./")
    # GitHub "blob" links to files -> raw files
    u = re.sub(r"^https://github\.com/([^/]+)/([^/]+)/blob/", r"https://raw.githubusercontent.com/\1/\2/", u)
    return clean(u)

NOISE = re.compile(r"shields\.io|badge|trendshift|star-history|starchart|contrib\.rocks|visitor|hits\.|"
                   r"buymeacoffee|ko-fi|sponsor|discord\.|twitter\.com/intent|api\.star|komarev|codecov|"
                   r"githubusercontent\.com/u/|avatars\.", re.I)

images, videos = [], []
def add(lst, u):
    u = absolute(u)
    if u and not NOISE.search(u) and u not in lst:
        lst.append(u)

VIDEO = re.compile(r"\.(mp4|mov|webm|m4v)(\?|$)|youtube\.com/watch|youtu\.be/|vimeo\.com/\d|"
                   r"github\.com/user-attachments/assets/|loom\.com/share", re.I)
for m in re.finditer(r"!\[[^\]]*\]\(([^)\s]+)[^)]*\)", text):
    add(videos if VIDEO.search(m.group(1)) else images, m.group(1))
for m in re.finditer(r"<img[^>]+src=[\"']([^\"']+)", text, re.I):
    add(images, m.group(1))
for m in re.finditer(r"<(?:video|source)[^>]+src=[\"']([^\"']+)", text, re.I):
    add(videos, m.group(1))
for m in re.finditer(r"https://[^\s)\"'<>\]]+", text):
    if VIDEO.search(m.group(0)):
        add(videos, m.group(0))

# Headings, and plain prose paragraphs for the summary.
heads, paras, buf, in_code = [], [], [], False
for line in text.splitlines():
    if line.strip().startswith(("```", "~~~")):
        in_code = not in_code; continue
    if in_code:
        continue
    h = re.match(r"^\s{0,3}(#{1,3})\s+(.*)", line)
    if h:
        t = clean(re.sub(r"<[^>]+>|[*_`]|!\[[^\]]*\]\([^)]*\)", "", h.group(2)))
        t = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", t).strip(" #")
        if t and len(heads) < 40:
            heads.append(t)
        if buf: paras.append(" ".join(buf)); buf = []
        continue
    s = line.strip()
    if not s or s.startswith(("|", ">", "<", "-", "*", "[!", "![", "---", "===")) or re.match(r"^\d+\.", s):
        if buf: paras.append(" ".join(buf)); buf = []
        continue
    buf.append(s)
if buf: paras.append(" ".join(buf))

def prose(p):
    p = re.sub(r"!\[[^\]]*\]\([^)]*\)", "", p)
    p = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", p)
    p = re.sub(r"<[^>]+>", "", p)
    p = html.unescape(re.sub(r"[*_`]{1,3}", "", p))
    return clean(re.sub(r"\s+", " ", p))

summary = []
for p in paras:
    p = prose(p)
    if len(p) >= 60 and not re.search(r"https?://", p) and len(summary) < 3:
        summary.append(p)
for s in summary: print("SUMMARY\t" + s[:600])
for h in heads:   print("HEAD\t" + h[:80])
for u in images[:6]: print("IMG\t" + u)
for u in videos[:6]: print("VID\t" + u)
PY
}

# Show one picture in the terminal if a viewer is installed. Downloads are capped at 8 MB.
ar_show_image() {
  local url="$1" f width
  width=$AR_PAGE_W; [ "$width" -gt $(( $(ar_cols) - 4 )) ] && width=$(( $(ar_cols) - 4 ))
  ar_have chafa || ar_have viu || ar_have img2sixel || return 1
  mkdir -p "$AR_CACHE/img" || return 1
  f="$AR_CACHE/img/$(printf '%s' "$url" | cksum | cut -d' ' -f1)"
  [ -s "$f" ] || curl -fsSL --proto '=https' --max-time 20 --max-filesize 8000000 "$url" -o "$f" 2>/dev/null || return 1
  # Only render real images (PNG, JPEG, GIF, WebP).
  case "$(head -c 12 "$f" | od -An -c | tr -d ' \n')" in
    *PNG*|*GIF8*|*RIFF*WEBP*|377330377*) ;;
    *) rm -f "$f"; return 1 ;;
  esac
  if ar_have chafa; then
    # Centred in the window (chafa 1.14+); older versions draw it at the left edge.
    chafa --animate=off --align=top,center --view-size="$(ar_cols)x20" --size="${width}x20" "$f" 2>/dev/null </dev/null \
      || chafa --animate=off --size="${width}x20" "$f" 2>/dev/null </dev/null
  elif ar_have viu; then viu -w "$width" "$f" 2>/dev/null
  else img2sixel -w "$((width * 8))" "$f" 2>/dev/null; fi
}

ar_open_url() {
  local url="$1"
  case "$url" in https://*) ;; *) return 1 ;; esac
  if ar_have xdg-open; then xdg-open "$url" >/dev/null 2>&1 &
  elif ar_have open; then open "$url" >/dev/null 2>&1
  elif ar_have wslview; then wslview "$url" >/dev/null 2>&1 &
  else ar_info "Open this link in your browser: $url"; return 0; fi
  ar_ok "Opened in your browser."
}

# Full details page for one entry.
ar_details() {
  local id="$1" row name url desc readme parsed val n
  row="$(ar_get "$id")"; [ -n "$row" ] || ar_die "No entry called '$id'."
  name="$(printf '%s' "$row" | cut -f4)"; desc="$(printf '%s' "$row" | cut -f5)"; url="$(printf '%s' "$row" | cut -f6)"
  ar_title "$(ar_cap "$name") · Details"
  ar_wrap "$desc"
  ar_info "Reading the project page…"
  if ! ar_have python3; then ar_warn "Python3 is needed to read project pages."; ar_hint "Link: $url"; return 0; fi
  readme="$(ar_readme_file "$id" "$url")" || { ar_warn "Could not read the project page (offline, or no README)."; ar_hint "Link: $url"; return 0; }
  parsed="$(ar_readme_parse "$readme" "$(ar_raw_base "$url")")"
  if [ -z "$parsed" ]; then ar_warn "The project page has no readable text."; ar_hint "Link: $url"; return 0; fi

  if printf '%s\n' "$parsed" | grep -q '^SUMMARY'; then
    ar_section "From the project page"
    printf '%s\n' "$parsed" | awk -F'\t' '$1=="SUMMARY" {print $2}' | while IFS= read -r val; do
      ar_wrap "$val"; echo
    done
  fi
  if printf '%s\n' "$parsed" | grep -q '^HEAD'; then
    ar_section "What's inside"
    printf '%s\n' "$parsed" | awk -F'\t' '$1=="HEAD" {print $2}' | head -12 | while IFS= read -r val; do
      printf '%s%s•%s %s\n' "$AR_M" "$C_CYAN" "$C_RESET" "$val"
    done
  fi
  n="$(printf '%s\n' "$parsed" | grep -c '^IMG')"
  if [ "$n" -gt 0 ]; then
    ar_section "Pictures ($n)"
    # Prefer a real screenshot or animation over a logo or SVG (which terminal viewers cannot draw).
    local first; first="$(printf '%s\n' "$parsed" | awk -F'\t' '$1=="IMG" {print $2}' \
      | grep -iE '\.(png|jpe?g|gif|webp)(\?|$)' | grep -viE 'logo|icon|wordmark|banner' | head -1)"
    [ -n "$first" ] || first="$(printf '%s\n' "$parsed" | awk -F'\t' '$1=="IMG" {print $2}' | grep -iE '\.(png|jpe?g|gif|webp)(\?|$)' | head -1)"
    if [ -z "$first" ] || ! ar_show_image "$first"; then
      ar_hint "Install chafa or viu to see pictures here. Links:"
    fi
    printf '%s\n' "$parsed" | awk -F'\t' '$1=="IMG" {print $2}' | while IFS= read -r val; do
      printf '%s%s%s%s\n' "$AR_M" "$C_BLUE" "$val" "$C_RESET"
    done
  fi
  if printf '%s\n' "$parsed" | grep -q '^VID'; then
    ar_section "Videos"
    printf '%s\n' "$parsed" | awk -F'\t' '$1=="VID" {print $2}' | while IFS= read -r val; do
      printf '%s%s▶ %s%s\n' "$AR_M" "$C_MAG" "$val" "$C_RESET"
    done
    ar_hint "Videos play in your browser: choose Open On GitHub, or open a link above."
  fi
  echo
  ar_hint "Full page: $url"
  return 0
}
