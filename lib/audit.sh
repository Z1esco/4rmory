# audit.sh - scan skills with NVIDIA SkillSpector, Cisco Skill Scanner and a built-in check.
# Verdicts: clean | warn | danger. Results are logged to catalog/audit.tsv.

AR_AUDIT_LOG="$AR_DATA/audit.tsv"
AR_LAST_VERDICT=""; AR_LAST_REPORT=""

ar_audit_status() {
  [ -f "$AR_AUDIT_LOG" ] || return 0
  local line v
  line="$(awk -F'\t' -v id="$1" '$1==id {l=$0} END {print l}' "$AR_AUDIT_LOG")"
  [ -n "$line" ] || return 0
  v="$(printf '%s' "$line" | cut -f3)"
  case "$v" in
    clean) printf '%s' "${C_GREEN}Clean${C_RESET}" ;;
    warn) printf '%s' "${C_YELLOW}Needs review${C_RESET}" ;;
    danger) printf '%s' "${C_RED}High risk${C_RESET}" ;;
    *) printf '%s' "$v" ;;
  esac
  printf ' %s(%s, %s)%s' "$C_GREY" "$(printf '%s' "$line" | cut -f2)" "$(printf '%s' "$line" | cut -f4)" "$C_RESET"
}


# ar_json_verdict scanner file -> "verdict summary" plus one line per finding.
ar_json_verdict() {
  python3 -I - "$1" "$2" <<'PY' 2>/dev/null || echo "warn scanner output unreadable"
import json, sys
kind, path = sys.argv[1], sys.argv[2]
d = json.load(open(path))
rank = {"CRITICAL": 4, "HIGH": 3, "MEDIUM": 2, "LOW": 1, "INFO": 0}
if kind == "skillspector":
    ra = d.get("risk_assessment", {})
    items = [(i.get("severity", ""), (i.get("location") or {}).get("file", ""), (i.get("location") or {}).get("start_line", ""),
              i.get("title") or i.get("description") or i.get("category") or "") for i in d.get("issues", [])]
    top = ra.get("max_issue_severity", "INFO")
    rec = str(ra.get("recommendation", "")).upper()
    head = f"recommendation={rec} score={ra.get('score')}"
else:
    skills = d.get("results", [d])  # scan-all wraps one result per skill
    items = [(f.get("severity", ""), f.get("file_path", ""), f.get("line_number", ""), f.get("title", ""))
             for x in skills for f in x.get("findings", [])]
    sevs = [str(x.get("max_severity", "INFO")).upper() for x in skills] or ["INFO"]
    top = max(sevs, key=lambda v: rank.get(v, 0))
    unsafe = [x.get("skill_name") for x in skills if x.get("is_safe") is False]
    d = {"is_safe": not unsafe}
    head = f"is_safe={not unsafe} skills={len(skills)}" + (f" unsafe={','.join(map(str, unsafe))}" if unsafe else "")
r = rank.get(str(top).upper(), 0)
if kind == "skillspector":
    v = "danger" if rec == "DO_NOT_INSTALL" else "warn" if rec in ("CAUTION", "REVIEW") or r >= 2 else "clean"
else:
    v = "danger" if d.get("is_safe") is False and r >= 3 else "warn" if r >= 2 or d.get("is_safe") is False else "clean"
print(f"{v} max={top} findings={len(items)} {head}")
for sev, f, line, t in items[:40]:
    print(f"  {sev}\t{f}:{line}\t{str(t)[:120]}")
PY
}

# Built-in check: patterns that are rare in honest skills and common in malicious ones.
# Prints findings as "LEVEL<TAB>file:line<TAB>reason".
ar_builtin_scan() {
  local dir="$1"
  local high='curl[^|]*\|[[:space:]]*(ba)?sh|wget[^|]*\|[[:space:]]*(ba)?sh|base64[[:space:]]+(-d|--decode)[^|]*\|[[:space:]]*(ba)?sh|eval[[:space:]]*\([[:space:]]*(atob|Buffer\.from)|nc[[:space:]]+-e|/dev/tcp/|rm[[:space:]]+-rf[[:space:]]+(/|~|\$HOME)([[:space:]]|$)|ignore (all )?(previous|prior) instructions|do not (tell|inform) the user|\.ssh/id_|\.aws/credentials|discord(app)?\.com/api/webhooks|api\.telegram\.org/bot|xmrig|stratum\+tcp'
  local medium='chmod[[:space:]]+(\+x|777)|crontab|sudo[[:space:]]|\.bashrc|\.zshrc|keychain|browser.*cookies|exfiltrat|pastebin\.com|ngrok|requests\.post\(|eval\(|exec\('
  grep -rInE --binary-files=without-match --exclude-dir=.git --exclude-dir=node_modules -i "$high" "$dir" 2>/dev/null \
    | head -40 | sed "s#^$dir/##" | awk -F: '{f=$1":"$2; $1="";$2=""; sub(/^  /,""); printf "HIGH\t%s\t%s\n", f, substr($0,1,140)}'
  grep -rInE --binary-files=without-match --exclude-dir=.git --exclude-dir=node_modules \
    --include='*.sh' --include='*.py' --include='*.js' --include='*.ts' --include='SKILL.md' -i "$medium" "$dir" 2>/dev/null \
    | head -40 | sed "s#^$dir/##" | awk -F: '{f=$1":"$2; $1="";$2=""; sub(/^  /,""); printf "MEDIUM\t%s\t%s\n", f, substr($0,1,140)}'
}

# Run a scanner with a time limit: ARMORY_SCAN_TIMEOUT seconds (default 900), when `timeout` exists.
ar_timed() {
  local t="${ARMORY_SCAN_TIMEOUT:-900}"
  if ar_have timeout; then timeout -k 10 "$t" "$@"
  elif ar_have gtimeout; then gtimeout -k 10 "$t" "$@"
  else "$@"; fi
}

# Run every available scanner on a folder. Sets AR_LAST_VERDICT and AR_LAST_REPORT.
ar_audit_dir() {
  local id="$1" dir="$2" report used="builtin" verdict=clean out ss_v="" cs_v=""
  ar_init_data
  report="$AR_REPORTS/$id.txt"; : > "$report"
  ar_info "Scanning $id for malware and risky behaviour…"

  local js="$AR_REPORTS/$id"
  rm -f "$js.skillspector.json" "$js.cisco.json"  # never read a stale report after a timeout
  if ar_have skillspector; then
    used="$used+skillspector"
    ar_timed skillspector scan "$dir" --no-llm --format json --output "$js.skillspector.json" >/dev/null 2>&1
    out="$(ar_json_verdict skillspector "$js.skillspector.json")"
    printf '== NVIDIA SkillSpector: %s\n\n' "$out" >> "$report"
    ss_v="${out%% *}"
  fi

  if ar_have skill-scanner; then
    used="$used+cisco"
    # A repo of many skills has no SKILL.md at its root: use Cisco's multi-skill mode.
    if [ -f "$dir/SKILL.md" ]; then
      ar_timed skill-scanner scan "$dir" --format json > "$js.cisco.json" 2>/dev/null
    else
      ar_timed skill-scanner scan-all "$dir" --recursive --format json > "$js.cisco.json" 2>/dev/null
    fi
    out="$(ar_json_verdict cisco "$js.cisco.json")"
    printf '== Cisco Skill Scanner: %s\n\n' "$out" >> "$report"
    cs_v="${out%% *}"
  fi
  # High risk only when every scanner that ran agrees; one alone means "needs review".
  if [ -n "$ss_v$cs_v" ]; then
    if [ "${ss_v:-danger}" = danger ] && [ "${cs_v:-danger}" = danger ]; then verdict=danger
    elif [ "${ss_v:-clean}" != clean ] || [ "${cs_v:-clean}" != clean ]; then verdict=warn; fi
  fi

  out="$(ar_builtin_scan "$dir")"
  printf '== 4rmory built-in check (advisory)\n%s\n' "${out:-no findings}" >> "$report"
  # The built-in grep is advisory: it only decides when no real scanner is installed.
  [ -z "$ss_v$cs_v" ] && [ -n "$out" ] && verdict=warn

  AR_LAST_VERDICT="$verdict"; AR_LAST_REPORT="$report"
  [ -f "$AR_AUDIT_LOG" ] || printf '# id\tdate\tverdict\tscanners\n' > "$AR_AUDIT_LOG"
  printf '%s\t%s\t%s\t%s\n' "$id" "$(date +%F)" "$verdict" "$used" >> "$AR_AUDIT_LOG"
  case "$verdict" in
    clean) ar_ok "Clean. No problems found ($used)." ;;
    warn) ar_warn "Needs review: a scanner flagged something ($used). Report: $report" ;;
    danger) ar_err "High risk: the scanners agree this looks dangerous ($used). Report: $report" ;;
  esac
  [ "$used" = builtin ] && ar_hint "Tip: install NVIDIA SkillSpector and Cisco skill-scanner for deeper scans (4rmory doctor)."
  return 0
}

# Download a repository link and scan it. Used before an entry is saved, so it works for ids
# that are not in any catalog yet. A stale copy from a different link is replaced.
ar_scan_url() {
  local id="$1" url="$2" split clone_url sub dest dir
  ar_init_data
  split="$(ar_split_url "$url")"; clone_url="${split%%$'\t'*}"; sub="${split#*$'\t'}"
  dest="$AR_REPOS/$id"
  if [ -d "$dest/.git" ] && [ "$(git -C "$dest" remote get-url origin 2>/dev/null)" != "$clone_url" ]; then
    rm -rf "$dest"
  fi
  ar_clone "$id" "$clone_url"
  dir="$dest"; [ -n "$sub" ] && dir="$dir/$sub"
  [ -d "$dir" ] || ar_die "Folder '$sub' not found inside $clone_url."
  ar_audit_dir "$id" "$dir"
}

# Scan before a new or changed link is saved. Returns 0 to go ahead, 1 to stop.
# High risk stops unless forced; Needs review asks (-y answers yes).
ar_scan_gate() {
  local id="$1" url="$2" force="$3" retry="$4"
  ar_scan_url "$id" "$url"
  case "$AR_LAST_VERDICT" in
    danger)
      if [ -n "$force" ]; then ar_warn "Saved despite high risk (--force). Report: $AR_LAST_REPORT"; return 0; fi
      ar_err "Not saved: the scan found high-risk findings. Report: $AR_LAST_REPORT"
      ar_hint "Read the report first. If you have checked it and trust it, run $retry again with --force."
      return 1 ;;
    warn)
      [ -n "$force" ] && return 0
      ar_confirm "A scanner flagged something (report above). Save it anyway?" && return 0
      ar_info "Not saved. Read the report to decide: $AR_LAST_REPORT"
      return 1 ;;
  esac
  return 0
}

# Latest logged verdict for an id from today, if any.
ar_today_verdict() {
  [ -f "$AR_AUDIT_LOG" ] || return 0
  awk -F'\t' -v id="$1" -v d="$(date +%F)" '$1==id && $2==d {v=$3} END {print v}' "$AR_AUDIT_LOG"
}

# Check and scan every shared-catalog row added or changed since a git ref (default HEAD).
# Fails (returns 1) on a malformed row or a High-risk verdict. Used by publish and by CI.
# With reuse=1, a verdict already logged today for that id is reused instead of re-scanning.
ar_audit_changed() {
  local base="${1:-HEAD}" reuse="${2:-}" rows id cat kind name desc url v bad=0 n=0 table=""
  [ -d "$AR_HOME/.git" ] || ar_die "Needs a git clone of 4rmory."
  git -C "$AR_HOME" rev-parse -q --verify "$base^{commit}" >/dev/null || ar_die "Unknown git ref '$base'."
  rows="$(git -C "$AR_HOME" diff -U0 "$base" -- catalog/armory.tsv | grep '^+[^+#]' | cut -c2-)"
  if [ -z "$rows" ]; then ar_info "No new or changed catalog entries."; return 0; fi
  ar_title "Scanning New And Changed Entries"
  while IFS= read -r row <&3; do  # fd 3: scanners and git must not eat the rows from stdin
    [ -n "$row" ] || continue
    n=$((n + 1))
    IFS=$'\t' read -r id cat kind name desc url <<< "$row"
    if [ "$(printf '%s' "$row" | awk -F'\t' '{print NF}')" != 6 ] || ! ar_valid_id "$id" || ! ar_valid_category "$cat" \
       || ! ar_valid_kind "$kind" || ! ar_valid_url "$url" || [ -z "$name" ] || [ -z "$desc" ]; then
      ar_err "Malformed row for '${id:-?}': need 6 tab-separated fields, a valid id, category, kind and https repo link."
      v=invalid; bad=1
    elif [ "$(grep -v '^#' "$AR_CATALOG" | awk -F'\t' -v id="$id" '$1==id' | wc -l | tr -d ' ')" -gt 1 ]; then
      ar_err "Duplicate id '$id' in the catalog."; v=duplicate; bad=1
    else
      v=""; [ -n "$reuse" ] && v="$(ar_today_verdict "$id")"
      if [ -n "$v" ]; then ar_info "$id: already scanned today ($v)."
      else ar_scan_url "$id" "$url"; v="$AR_LAST_VERDICT"; fi
      [ "$v" = danger ] && bad=1
    fi
    table="$table| \`$id\` | $(printf '%s' "$name" | tr '|`' '/ ') | $v |"$'\n'
  done 3<<< "$rows"
  printf '\n'
  ar_info "$n entr$( [ "$n" = 1 ] && echo y || echo ies) checked."
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    { printf '## 4rmory catalog scan\n\n| Id | Name | Verdict |\n|---|---|---|\n%s\n' "$table"
      printf 'Verdicts: clean · warn = needs review (one scanner flagged it) · danger = high risk (all scanners agree).\n'; } >> "$GITHUB_STEP_SUMMARY"
  fi
  if [ "$bad" = 1 ]; then ar_err "Some entries are malformed or high risk. See the reports above."; return 1; fi
  ar_ok "No high-risk entries."
}

ar_audit() {
  local target="$1" id dir url split
  case "$target" in
    "") ar_die "Usage: 4rmory audit <id> | --installed | --all-skills | --changed [git-ref] | <folder>" ;;
    --changed) ar_audit_changed "${2:-HEAD}" ;;
    --installed)
      [ -d "$AR_REPOS" ] || ar_die "Nothing installed."
      for dir in "$AR_REPOS"/*/; do [ -d "$dir" ] && ar_audit_dir "$(basename "$dir")" "$dir"; done ;;
    --all-skills)
      ar_rows | awk -F'\t' '$3=="skill" || $3=="collection" {print $1}' | while IFS= read -r id; do
        ar_audit "$id" || true
      done ;;
    *)
      if [ -d "$target" ]; then ar_audit_dir "$(ar_slug "$(basename "$target")")" "$target"; return; fi
      id="$target"; url="$(ar_field "$id" 6)"; [ -n "$url" ] || ar_die "No entry called '$id'."
      ar_init_data
      split="$(ar_split_url "$url")"
      ar_clone "$id" "${split%%$'\t'*}"
      dir="$AR_REPOS/$id"; [ -n "${split#*$'\t'}" ] && dir="$dir/${split#*$'\t'}"
      ar_audit_dir "$id" "$dir" ;;
  esac
}
