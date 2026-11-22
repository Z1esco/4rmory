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
    items = [(f.get("severity", ""), f.get("file_path", ""), f.get("line_number", ""), f.get("title", "")) for f in d.get("findings", [])]
    top = d.get("max_severity", "INFO")
    head = f"is_safe={d.get('is_safe')}"
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

# Run every available scanner on a folder. Sets AR_LAST_VERDICT and AR_LAST_REPORT.
ar_audit_dir() {
  local id="$1" dir="$2" report used="builtin" verdict=clean out ss_v="" cs_v=""
  ar_init_data
  report="$AR_REPORTS/$id.txt"; : > "$report"
  ar_info "Scanning $id for malware and risky behaviour…"

  local js="$AR_REPORTS/$id"
  if ar_have skillspector; then
    used="$used+skillspector"
    skillspector scan "$dir" --no-llm --format json --output "$js.skillspector.json" >/dev/null 2>&1
    out="$(ar_json_verdict skillspector "$js.skillspector.json")"
    printf '== NVIDIA SkillSpector: %s\n\n' "$out" >> "$report"
    ss_v="${out%% *}"
  fi

  if ar_have skill-scanner; then
    used="$used+cisco"
    skill-scanner scan "$dir" --format json > "$js.cisco.json" 2>/dev/null
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

ar_audit() {
  local target="$1" id dir url split
  case "$target" in
    "") ar_die "Usage: 4rmory audit <id> | --installed | --all-skills | <folder>" ;;
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
