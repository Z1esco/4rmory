# install.sh - clone repos, link skills into agents, update and uninstall.

ar_is_installed() { [ -f "$AR_INSTALLED" ] && awk -F'\t' -v id="$1" '$1==id {f=1} END {exit !f}' "$AR_INSTALLED"; }

# Split a catalog URL into clone URL and optional sub-folder (for /tree/<branch>/<path> links).
ar_split_url() {
  local url="$1" base rest
  case "$url" in
    */tree/*)
      base="${url%%/tree/*}"; rest="${url#*/tree/}"
      printf '%s\t%s\n' "$base" "${rest#*/}" ;;
    *) printf '%s\t\n' "$url" ;;
  esac
}

ar_clone() {
  local id="$1" url="$2" dest="$AR_REPOS/$1"
  if [ -d "$dest/.git" ]; then
    ar_info "Updating existing copy of $id…"
    git -C "$dest" pull --ff-only -q || ar_warn "Could not update $id; using the copy you have."
  else
    ar_info "Downloading $id…"
    GIT_TERMINAL_PROMPT=0 git clone --depth 1 -q -- "$url" "$dest" || ar_die "Download failed: $url"
  fi
}

# Folders that hold a SKILL.md, relative to $1.
ar_find_skills() {
  find "$1" -maxdepth 5 -name SKILL.md -not -path '*/.git/*' -not -path '*/node_modules/*' 2>/dev/null \
    | sed 's#/SKILL.md$##' | sort
}

ar_install() {
  local id="" agent="" force="" noaudit="" pick=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --agent|-a) agent="$2"; shift ;;
      --force) force=1 ;;
      --no-audit) noaudit=1 ;;
      --all) pick=all ;;
      -*) ar_die "Unknown option $1" ;;
      *) id="$1" ;;
    esac
    shift
  done
  [ -n "$id" ] || ar_die "Usage: 4rmory install <id> [--agent claude|codex|opencode|agents] [--all]"
  local row; row="$(ar_get "$id")"; [ -n "$row" ] || ar_die "No entry called '$id'. Try: 4rmory search $id"
  ar_have git || ar_die "git is required. Install git and try again."
  ar_init_data
  local url kind split clone_url sub src
  url="$(printf '%s' "$row" | cut -f6)"; kind="$(printf '%s' "$row" | cut -f3)"
  split="$(ar_split_url "$url")"; clone_url="${split%%$'\t'*}"; sub="${split#*$'\t'}"
  ar_title "Installing $(printf '%s' "$row" | cut -f4)"
  ar_clone "$id" "$clone_url"
  src="$AR_REPOS/$id"; [ -n "$sub" ] && src="$src/$sub"
  [ -d "$src" ] || ar_die "Folder '$sub' not found inside the repository."

  if [ -z "$noaudit" ]; then
    ar_audit_dir "$id" "$src"
    if [ "$AR_LAST_VERDICT" = "danger" ] && [ -z "$force" ]; then
      ar_err "Install stopped: the scan found high-risk findings. Report: $AR_LAST_REPORT"
      ar_hint "Read the report first. To install anyway: 4rmory install $id --force"
      return 1
    fi
    if [ "$AR_LAST_VERDICT" = "warn" ] && [ -z "$force" ]; then
      # AR_WARN_POLICY (batch installs): ask (default) | skip | yes
      case "${AR_WARN_POLICY:-ask}" in
        skip) ar_info "Skipped: a scanner flagged it. Report: $AR_LAST_REPORT"; return 2 ;;
        yes) ar_info "Installing although a scanner flagged it (your choice)." ;;
        *) ar_confirm "Install anyway?" || { ar_info "Not installed. Read the report above to decide."; return 2; } ;;
      esac
    fi
  fi

  local skills; skills="$(ar_find_skills "$src")"
  if [ -z "$skills" ]; then
    ar_ok "Downloaded to $src"
    ar_hint "This is a $(ar_cap "$kind"), not an agent skill. Follow its README to set it up."
    printf '%s\t-\t%s\t%s\n' "$id" "$src" "$(date +%F)" >> "$AR_INSTALLED"
    return 0
  fi

  [ -n "$agent" ] || agent="$(ar_pick_agent)" || ar_die "Cancelled."
  local target; target="$(ar_agent_dir "$agent")" || ar_die "Unknown agent '$agent'. Use: $AR_AGENTS"
  mkdir -p "$target"
  local count; count="$(printf '%s\n' "$skills" | wc -l | tr -d ' ')"
  local chosen="$skills"
  if [ "$count" -gt 1 ] && [ "$pick" != all ] && [ -t 0 ] && [ -z "${AR_YES:-}" ]; then
    ar_info "$count skills found in this repository."
    if ! ar_confirm "Install all $count?"; then
      local names=() d
      while IFS= read -r d; do names+=("$(basename "$d")"); done <<< "$skills"
      local one; one="$(ar_choose "Pick one skill" "${names[@]}")" || ar_die "Cancelled."
      chosen="$(printf '%s\n' "$skills" | awk -v n="$one" -F/ '$NF==n' | head -1)"
    fi
  fi
  local d name link n=0
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    name="$(basename "$d")"; ar_valid_id "$(ar_slug "$name")" || continue
    link="$target/$name"
    if [ -e "$link" ] && [ ! -L "$link" ]; then
      ar_warn "Skipped $name: $link already exists and is not managed by 4rmory."
      continue
    fi
    ln -sfn "$d" "$link"
    printf '%s\t%s\t%s\t%s\n' "$id" "$agent" "$link" "$(date +%F)" >> "$AR_INSTALLED"
    n=$((n + 1))
  done <<< "$chosen"
  ar_ok "Linked $n skill(s) into $target"
  ar_hint "Restart $(ar_cap "$agent") to load them."
}

ar_uninstall() {
  local id="$1" p
  [ -n "$id" ] || ar_die "Usage: 4rmory uninstall <id>"
  ar_is_installed "$id" || ar_die "'$id' is not installed."
  ar_confirm "Uninstall '$id' (remove its links and downloaded copy)?" || { ar_info "Kept."; return 0; }
  awk -F'\t' -v id="$id" '$1==id {print $3}' "$AR_INSTALLED" | while IFS= read -r p; do
    [ -L "$p" ] && rm -f "$p"
  done
  case "$id" in ''|*/*|.*) ar_die "Refusing unsafe id." ;; esac
  [ -d "$AR_REPOS/$id" ] && rm -rf -- "${AR_REPOS:?}/$id"
  local tmp; tmp="$(mktemp)"; awk -F'\t' -v id="$id" '$1!=id' "$AR_INSTALLED" > "$tmp" && mv "$tmp" "$AR_INSTALLED"
  ar_ok "Uninstalled $id."
}

ar_installed() {
  ar_title "My Installed Skills"
  [ -f "$AR_INSTALLED" ] && [ "$(grep -vc '^#' "$AR_INSTALLED")" -gt 0 ] || { ar_hint "Nothing yet. Try: 4rmory setup"; return 0; }
  grep -v '^#' "$AR_INSTALLED" | awk -F'\t' '{print $1}' | sort -u | while IFS= read -r id; do
    local agents; agents="$(awk -F'\t' -v id="$id" '$1==id && $2!="-" {print $2}' "$AR_INSTALLED" | sort -u | tr '\n' ' ')"
    local n; n="$(awk -F'\t' -v id="$id" '$1==id && $2!="-"' "$AR_INSTALLED" | wc -l | tr -d ' ')"
    local nm; nm="$(ar_field "$id" 4)"; [ -n "$nm" ] || nm="$id"
    local ag=""; for a in $agents; do ag="$ag$(ar_cap "$a") "; done
    if [ "$n" -gt 0 ]; then printf '%s  %s✔%s %s%-30s%s %s%s Skill(s) · %s%s\n' "$AR_M" "$C_GREEN" "$C_RESET" "$C_BOLD" "$(ar_cap "$nm")" "$C_RESET" "$C_GREY" "$n" "$ag" "$C_RESET"
    else printf '%s  %s✔%s %s%-30s%s %sDownloaded Tool%s\n' "$AR_M" "$C_GREEN" "$C_RESET" "$C_BOLD" "$(ar_cap "$nm")" "$C_RESET" "$C_GREY" "$C_RESET"; fi
  done
}

ar_update() {
  ar_title "Update"
  if [ -d "$AR_HOME/.git" ]; then
    local before after new
    before="$(ar_rows | cut -f1 | sort)"
    ar_info "Getting the newest catalog…"
    if git -C "$AR_HOME" pull --rebase --autostash -q 2>/dev/null; then
      after="$(ar_rows | cut -f1 | sort)"
      new="$(comm -13 <(printf '%s\n' "$before") <(printf '%s\n' "$after"))"
      date +%s > "$AR_DATA/last-check" 2>/dev/null
      if [ -n "$new" ]; then
        ar_ok "$(printf '%s\n' "$new" | wc -l | tr -d ' ') New skill(s) and tool(s):"
        printf '%s\n' "$new" | while IFS= read -r id; do printf '    %s+%s %s %s· %s%s\n' "$C_GREEN" "$C_RESET" "$(ar_field "$id" 4)" "$C_GREY" "$(ar_cap "$(ar_field "$id" 2)")" "$C_RESET"; done
      else
        ar_ok "Catalog is up to date ($(ar_rows | wc -l | tr -d ' ') entries)."
      fi
    else
      ar_warn "Could not reach GitHub. Check your internet and try again."
    fi
  else
    ar_warn "This copy of 4rmory was not installed with git, so it cannot update itself."
    ar_hint "Reinstall: git clone https://github.com/Z1esco/4rmory.git && cd 4rmory && ./install.sh"
  fi
  [ -d "$AR_REPOS" ] || return 0
  local d any=""
  for d in "$AR_REPOS"/*/; do
    [ -d "$d/.git" ] || continue
    [ -z "$any" ] && { ar_info "Updating your installed skills…"; any=1; }
    if git -C "$d" pull --ff-only -q 2>/dev/null; then ar_ok "$(basename "$d")"; else ar_warn "$(basename "$d") could not update"; fi
  done
  [ -n "$any" ] && ar_hint "Re-scan after updating: 4rmory audit --installed"
  return 0
}

# Quietly check GitHub (at most every 6 hours) and echo how many catalog updates wait.
ar_pending_updates() {
  [ -d "$AR_HOME/.git" ] || return 0
  local now last=0 stamp="$AR_DATA/last-check"
  now="$(date +%s)"; [ -f "$stamp" ] && last="$(cat "$stamp" 2>/dev/null || echo 0)"
  if [ $((now - ${last:-0})) -gt 21600 ]; then
    mkdir -p "$AR_DATA"; printf '%s' "$now" > "$stamp"
    if ar_have timeout; then GIT_TERMINAL_PROMPT=0 timeout 6 git -C "$AR_HOME" fetch -q 2>/dev/null
    else GIT_TERMINAL_PROMPT=0 git -C "$AR_HOME" fetch -q 2>/dev/null; fi
  fi
  git -C "$AR_HOME" rev-list --count 'HEAD..@{u}' -- catalog/armory.tsv 2>/dev/null
}

# Guided first run: pick an agent, pick categories, install the skills in them.
# ar_parse_picks "1-3,5" max -> one number per line, or nothing if the text is not a valid pick.
ar_parse_picks() {
  local text="${1// /}" max="$2" part a b i out=""
  case "$text" in ''|*[!0-9,-]*) return 1 ;; esac
  local IFS=,
  for part in $text; do
    case "$part" in
      *-*) a="${part%-*}"; b="${part#*-}" ;;
      *) a="$part"; b="$part" ;;
    esac
    case "$a" in ''|*[!0-9]*) return 1 ;; esac
    case "$b" in ''|*[!0-9]*) return 1 ;; esac
    [ "$a" -ge 1 ] && [ "$b" -le "$max" ] && [ "$a" -le "$b" ] || return 1
    for ((i = a; i <= b; i++)); do out="$out$i"$'\n'; done
  done
  printf '%s' "$out" | awk 'NF && !seen[$0]++'
}

# Install several entries in one go: pick the agent once, choose what to do with "Needs review",
# then each entry is scanned and installed. High risk is always blocked.
ar_install_many() {
  local agent="" ids=() id ok=0 skipped=0 blocked=0 rc policy
  for id in "$@"; do ids+=("$id"); done
  [ ${#ids[@]} -gt 0 ] || { ar_info "Nothing to install."; return 0; }
  ar_title "Install ${#ids[@]} At Once"
  for id in "${ids[@]}"; do
    printf '%s  %s•%s %s %s(%s)%s\n' "$AR_M" "$C_CYAN" "$C_RESET" "$(ar_cap "$(ar_field "$id" 4)")" "$C_GREY" "$(ar_cap "$(ar_field "$id" 3)")" "$C_RESET"
  done
  if [ -n "${AR_AGENT:-}" ]; then agent="$AR_AGENT"; else agent="$(ar_pick_agent)" || { ar_info "Cancelled."; return 0; }; fi
  ar_agent_dir "$agent" >/dev/null || ar_die "Unknown agent '$agent'. Use: $AR_AGENTS"
  if [ -n "${AR_WARN_POLICY:-}" ]; then policy="$AR_WARN_POLICY"
  elif [ -n "${AR_YES:-}" ]; then policy=yes
  else
    policy="$(ar_choose "If a scanner says Needs review" "Ask me each time" "Skip it" "Install it anyway")" || { ar_info "Cancelled."; return 0; }
    case "$policy" in Skip*) policy=skip ;; Install*) policy=yes ;; *) policy=ask ;; esac
  fi
  ar_confirm "Scan and install these ${#ids[@]} for $(ar_cap "$agent")?" || { ar_info "Cancelled."; return 0; }
  for id in "${ids[@]}"; do
    printf '\n'; ar_rule
    ( AR_WARN_POLICY="$policy" ar_install "$id" --agent "$agent" --all ); rc=$?
    case "$rc" in 0) ok=$((ok + 1)) ;; 2) skipped=$((skipped + 1)) ;; *) blocked=$((blocked + 1)) ;; esac
  done
  printf '\n'; ar_rule
  ar_ok "Done: $ok installed · $skipped skipped (needs review) · $blocked blocked or failed."
  [ "$blocked" -gt 0 ] && ar_hint "Blocked ones were rated High risk or could not download. Reports: $AR_REPORTS"
  ar_hint "Restart $(ar_cap "$agent") to load new skills. See all: 4rmory installed"
  return 0
}

ar_setup() {
  ar_title "Guided Setup"
  ar_info "Pick your AI agent, then the areas you work in. 4rmory installs the agent skills for you,"
  ar_info "scanning each one for malware first."
  echo
  local agent; agent="$(ar_pick_agent)" || { ar_info "Cancelled."; return 0; }
  local cats=() c picked
  ar_info "Now pick the areas you work in, one at a time. Press Enter when you are done."
  while :; do
    picked="$(AR_BACK_LABEL=Done ar_pick_category)" || break
    cats+=("$picked")
    ar_ok "Added $(ar_cap "$picked")"
  done
  [ ${#cats[@]} -gt 0 ] || { ar_info "Nothing picked."; return 0; }
  local ids=()
  for c in "${cats[@]}"; do
    while IFS= read -r id; do [ -n "$id" ] && ids+=("$id"); done \
      < <(ar_rows | awk -F'\t' -v c="$c" '$2==c && $3=="skill" {print $1}')
  done
  [ ${#ids[@]} -gt 0 ] || { ar_warn "No installable agent skills in those areas. Browse tools with: 4rmory list <category>"; return 0; }
  AR_AGENT="$agent" ar_install_many "${ids[@]}"
}

ar_pick_agent() {
  local sel; sel="$(ar_choose "Your AI agent" "Claude $C_GREY· Claude Code$C_RESET" "Codex $C_GREY· OpenAI Codex CLI$C_RESET" "Opencode $C_GREY· OpenCode$C_RESET" "Agents $C_GREY· Any agent using ~/.agents/skills$C_RESET")" || return 1
  printf '%s' "${sel%% *}" | tr A-Z a-z
}
