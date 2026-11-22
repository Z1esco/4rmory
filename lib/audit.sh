# audit.sh - scan skills with NVIDIA SkillSpector, Cisco Skill Scanner and a built-in check.
# Verdicts: clean | warn | danger. Results are logged to catalog/audit.tsv.

AR_AUDIT_LOG="$AR_HOME/catalog/audit.tsv"
AR_LAST_VERDICT=""; AR_LAST_REPORT=""

ar_audit_status() {
  [ -f "$AR_AUDIT_LOG" ] || return 0
  local line v
  line="$(awk -F'\t' -v id="$1" '$1==id {l=$0} END {print l}' "$AR_AUDIT_LOG")"
  [ -n "$line" ] || return 0
  v="$(printf '%s' "$line" | cut -f3)"
  case "$v" in
    clean) printf '%s' "${C_GREEN}clean${C_RESET}" ;;
    warn) printf '%s' "${C_YELLOW}review${C_RESET}" ;;
    danger) printf '%s' "${C_RED}high risk${C_RESET}" ;;
    *) printf '%s' "$v" ;;
  esac
  printf ' %s(%s, %s)%s' "$C_GREY" "$(printf '%s' "$line" | cut -f2)" "$(printf '%s' "$line" | cut -f4)" "$C_RESET"
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
  local id="$1" dir="$2" report used="builtin" verdict=clean out rc
  ar_init_data
  report="$AR_REPORTS/$id.txt"; : > "$report"
  ar_info "Scanning $id for malware and risky behaviour…"

  if ar_have skillspector; then
    used="$used+skillspector"
    out="$(skillspector scan "$dir" --no-llm 2>&1)"; rc=$?
    printf '== NVIDIA SkillSpector (exit %s)\n%s\n\n' "$rc" "$out" >> "$report"
    if printf '%s' "$out" | grep -qiE '\b(critical|high)\b.*(risk|severity|finding)|verdict[^a-z]*(malicious|unsafe|block)|risk level[^a-z]*(high|critical)'; then verdict=danger
    elif printf '%s' "$out" | grep -qiE '\bmedium\b'; then verdict=warn; fi
  fi

  if ar_have skill-scanner; then
    used="$used+cisco"
    out="$(skill-scanner scan "$dir" 2>&1)"; rc=$?
    printf '== Cisco Skill Scanner (exit %s)\n%s\n\n' "$rc" "$out" >> "$report"
    if printf '%s' "$out" | grep -qiE 'severity[^a-z]*(critical|high)|\b(CRITICAL|HIGH)\b|is_safe[^a-z]*false'; then verdict=danger
    elif [ "$verdict" = clean ] && printf '%s' "$out" | grep -qE '\bMEDIUM\b'; then verdict=warn; fi
  fi

  out="$(ar_builtin_scan "$dir")"
  printf '== 4rmory built-in check\n%s\n' "${out:-no findings}" >> "$report"
  if printf '%s' "$out" | grep -q '^HIGH'; then [ "$verdict" = clean ] && verdict=warn; fi
  [ "$verdict" = clean ] && [ -n "$out" ] && verdict=warn

  AR_LAST_VERDICT="$verdict"; AR_LAST_REPORT="$report"
  if [ -w "$AR_AUDIT_LOG" ] || [ -w "$(dirname "$AR_AUDIT_LOG")" ]; then
    [ -f "$AR_AUDIT_LOG" ] || printf '# id\tdate\tverdict\tscanners\n' > "$AR_AUDIT_LOG"
    printf '%s\t%s\t%s\t%s\n' "$id" "$(date +%F)" "$verdict" "$used" >> "$AR_AUDIT_LOG"
  fi
  case "$verdict" in
    clean) ar_ok "No problems found ($used)." ;;
    warn) ar_warn "Some things need a human look ($used). Report: $report" ;;
    danger) ar_err "High-risk findings ($used). Report: $report" ;;
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
