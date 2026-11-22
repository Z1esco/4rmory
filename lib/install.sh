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
  fi

  local skills; skills="$(ar_find_skills "$src")"
  if [ -z "$skills" ]; then
    ar_ok "Downloaded to $src"
    ar_hint "This is a $kind, not an agent skill. Follow its README to set it up."
    printf '%s\t-\t%s\t%s\n' "$id" "$src" "$(date +%F)" >> "$AR_INSTALLED"
    return 0
  fi

  [ -n "$agent" ] || agent="$(ar_choose "Install skills for which agent" $AR_AGENTS)" || ar_die "Cancelled."
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
  ar_hint "Restart $agent to load them."
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
  ar_title "Installed"
  [ -f "$AR_INSTALLED" ] && [ "$(grep -vc '^#' "$AR_INSTALLED")" -gt 0 ] || { ar_hint "Nothing yet. Try: 4rmory setup"; return 0; }
  grep -v '^#' "$AR_INSTALLED" | awk -F'\t' '{print $1}' | sort -u | while IFS= read -r id; do
    local agents; agents="$(awk -F'\t' -v id="$id" '$1==id && $2!="-" {print $2}' "$AR_INSTALLED" | sort -u | tr '\n' ' ')"
    local n; n="$(awk -F'\t' -v id="$id" '$1==id && $2!="-"' "$AR_INSTALLED" | wc -l | tr -d ' ')"
    printf '  %s%-28s%s %s\n' "$C_BOLD" "$id" "$C_RESET" "${C_GREY}${n} skill link(s) ${agents:+· $agents}${C_RESET}"
  done
}

ar_update() {
  ar_title "Updating"
  if [ -d "$AR_HOME/.git" ]; then
    git -C "$AR_HOME" pull --ff-only -q && ar_ok "4rmory and catalog are up to date." || ar_warn "Could not update 4rmory itself."
  fi
  [ -d "$AR_REPOS" ] || return 0
  local d
  for d in "$AR_REPOS"/*/; do
    [ -d "$d/.git" ] || continue
    if git -C "$d" pull --ff-only -q 2>/dev/null; then ar_ok "$(basename "$d")"; else ar_warn "$(basename "$d") could not update"; fi
  done
  ar_hint "Re-scan after updating: 4rmory audit --installed"
}

# Guided first run: pick an agent, pick categories, install the skills in them.
ar_setup() {
  ar_banner
  ar_title "Setup"
  ar_info "Pick your AI agent, then the areas you work in. 4rmory installs the agent skills for you,"
  ar_info "scanning each one for malware first."
  echo
  local agent; agent="$(ar_choose "Your agent" $AR_AGENTS)" || ar_die "Cancelled."
  local cats=() c picked
  while :; do
    picked="$(ar_choose "Add an area (blank when done)" $AR_CATEGORIES)" || break
    cats+=("$picked")
    ar_ok "Added $picked"
  done
  [ ${#cats[@]} -gt 0 ] || { ar_info "Nothing picked."; return 0; }
  local ids=()
  for c in "${cats[@]}"; do
    while IFS= read -r id; do [ -n "$id" ] && ids+=("$id"); done \
      < <(ar_rows | awk -F'\t' -v c="$c" '$2==c && $3=="skill" {print $1}')
  done
  [ ${#ids[@]} -gt 0 ] || { ar_warn "No installable agent skills in those areas. Browse tools with: 4rmory list <category>"; return 0; }
  ar_info "Skills to install: ${ids[*]}"
  ar_confirm "Install these ${#ids[@]} skill packs for $agent?" || return 0
  local id
  for id in "${ids[@]}"; do AR_YES=1 ar_install "$id" --agent "$agent" --all || true; done
  ar_ok "Setup finished. See what you have: 4rmory installed"
}
