# catalog.sh - read and change catalog/armory.tsv
# Columns: id  category  kind  name  description  url

AR_CATEGORIES="essentials design engineering copywriting social youtube motion image audio fiction editing research security automation docs data product collections"
AR_KINDS="skill tool mcp collection"

ar_cat_label() {
  case "$1" in
    essentials) echo "Start here: must-have agent skills" ;;
    design) echo "UI/UX, web design and anti-slop" ;;
    engineering) echo "Code understanding and software engineering" ;;
    copywriting) echo "Copywriting, marketing and brand voice" ;;
    social) echo "Captions and social media" ;;
    youtube) echo "YouTube and creator workflows" ;;
    motion) echo "Motion design, animation and game visuals" ;;
    image) echo "Image generation and visual AI" ;;
    audio) echo "Audio, voice and speech-to-text" ;;
    fiction) echo "Novels, fiction and screenwriting" ;;
    editing) echo "Humanizer, editing and natural writing" ;;
    research) echo "Research, OSINT and knowledge work" ;;
    security) echo "Cybersecurity and secure AI agents" ;;
    automation) echo "Automation, agents and MCP" ;;
    docs) echo "Documents, reports and knowledge bases" ;;
    data) echo "Data, analytics and machine learning" ;;
    product) echo "Product, SaaS and growth" ;;
    collections) echo "Big lists to discover more" ;;
    *) echo "$1" ;;
  esac
}

ar_valid_category() { case " $AR_CATEGORIES " in *" $1 "*) return 0 ;; esac; return 1; }
ar_valid_kind() { case " $AR_KINDS " in *" $1 "*) return 0 ;; esac; return 1; }

# Shared catalog (updated with `4rmory update`) + your personal list ($AR_MY,
# same id overrides) minus ids you hid ($AR_HIDDEN).
ar_rows() {
  local my="/dev/null" hidden="/dev/null"
  [ -f "$AR_MY" ] && my="$AR_MY"; [ -f "$AR_HIDDEN" ] && hidden="$AR_HIDDEN"
  awk -F'\t' -v H="$hidden" -v M="$my" '
    FILENAME == H { h[$1] = 1; next }
    /^#/ || /^[[:space:]]*$/ { next }
    FILENAME == M { mine[$1] = $0; ord[++m] = $1; next }
    !($1 in mine) && !($1 in h) { print }
    END { for (i = 1; i <= m; i++) if (!(ord[i] in h)) print mine[ord[i]] }
  ' "$hidden" "$my" "$AR_CATALOG"
}

ar_is_maintainer() { [ -n "${ARMORY_MAINTAINER:-}" ] || [ -f "$AR_DATA/maintainer" ]; }
ar_in_file() { [ -f "$2" ] && awk -F'\t' -v id="$1" '$1==id {f=1} END {exit !f}' "$2"; }
ar_official_has() { grep -v '^#' "$AR_CATALOG" | awk -F'\t' -v id="$1" '$1==id {f=1} END {exit !f}'; }

# Which file do your changes go to? Maintainers change the shared catalog.
ar_target_file() { if ar_is_maintainer; then printf '%s' "$AR_CATALOG"; else printf '%s' "$AR_MY"; fi; }

# ar_get id -> the full row, or nothing.
ar_get() { ar_rows | awk -F'\t' -v id="$1" '$1==id {print; exit}'; }
ar_field() { ar_get "$1" | cut -f"$2"; }

# Print rows as a neat list. AR_NUMBERED=1 adds number badges.
ar_print_rows() {
  local id cat kind name desc url width n=0 kc lead
  width=$(( $(ar_cols) - 8 )); [ "$width" -gt 92 ] && width=92; [ "$width" -lt 30 ] && width=30
  while IFS=$'\t' read -r id cat kind name desc url; do
    n=$((n + 1))
    kc="$(ar_kind_color "$kind")"
    [ ${#desc} -gt "$width" ] && desc="${desc:0:$((width - 1))}…"
    if [ -n "${AR_NUMBERED:-}" ]; then lead="  $(ar_pill "$n")  "; else lead="  "; fi
    printf '%s%s%s%s  %s%s%s · %s%s%s\n' "$lead" "$C_BOLD" "$(ar_cap "$name")" "$C_RESET" "$kc" "$(ar_cap "$kind")" "$C_RESET" "$C_GREY" "$(ar_cap "$cat")" "$C_RESET"
    printf '        %s%s%s\n' "$C_DIM" "$desc" "$C_RESET"
    [ -z "${AR_NUMBERED:-}" ] && printf '      %sId: %s%s\n' "$C_GREY" "$id" "$C_RESET"
  done
  if [ "$n" -eq 0 ]; then ar_warn "Nothing found. Try fewer or different words."
  elif [ -z "${AR_NUMBERED:-}" ]; then printf '\n%s  %d Result(s) · Details: 4rmory info <id>%s\n' "$C_GREY" "$n" "$C_RESET"; fi
  return 0
}

# ar_filter query category kind -> matching rows (case-insensitive, all words must match)
ar_filter() {
  ar_rows | awk -F'\t' -v q="$1" -v c="$2" -v k="$3" '
    BEGIN { n = split(tolower(q), w, /[[:space:]]+/) }
    {
      if (c != "" && $2 != c) next
      if (k != "" && $3 != k) next
      hay = tolower($1 " " $2 " " $3 " " $4 " " $5 " " $6)
      for (i = 1; i <= n; i++) if (w[i] != "" && index(hay, w[i]) == 0) next
      print
    }'
}

ar_cat_count() { ar_rows | awk -F'\t' -v c="$1" '$2==c' | wc -l | tr -d ' '; }

ar_categories() {
  ar_title "Categories"
  local c count
  for c in $AR_CATEGORIES; do
    count="$(ar_cat_count "$c")"; [ "$count" -eq 0 ] && continue
    printf '  %s%-13s%s %s%3s%s  %s\n' "$C_CYAN$C_BOLD" "$(ar_cap "$c")" "$C_RESET" "$C_YELLOW" "$count" "$C_RESET" "$(ar_cat_label "$c")"
  done
  ar_hint ""
  ar_hint "Browse One: 4rmory list <category>"
}

ar_info_card() {
  local row id cat kind name desc url
  row="$(ar_get "$1")"; [ -n "$row" ] || ar_die "No entry called '$1'. Try: 4rmory search $1"
  IFS=$'\t' read -r id cat kind name desc url <<< "$row"
  ar_title "$(ar_cap "$name")"
  printf '  %s%-10s%s %s\n' "$C_GREY" "Id" "$C_RESET" "$C_BOLD$id$C_RESET"
  printf '  %s%-10s%s %s\n' "$C_GREY" "Kind" "$C_RESET" "$(ar_kind_color "$kind")$(ar_cap "$kind")$C_RESET"
  printf '  %s%-10s%s %s · %s\n' "$C_GREY" "Category" "$C_RESET" "$(ar_cap "$cat")" "$(ar_cat_label "$cat")"
  printf '  %s%-10s%s %s\n' "$C_GREY" "Link" "$C_RESET" "$C_BLUE$url$C_RESET"
  printf '  %s%-10s%s %s\n' "$C_GREY" "About" "$C_RESET" "$desc"
  if ar_is_installed "$id"; then printf '  %s%-10s%s %s\n' "$C_GREY" "Status" "$C_RESET" "${C_GREEN}Installed${C_RESET}"
  else printf '  %s%-10s%s %s\n' "$C_GREY" "Status" "$C_RESET" "Not installed"; fi
  ar_in_file "$id" "$AR_MY" && printf '  %s%-10s%s %s\n' "$C_GREY" "Source" "$C_RESET" "Your personal list"
  local audit; audit="$(ar_audit_status "$id")"
  [ -n "$audit" ] && printf '  %s%-10s%s %s\n' "$C_GREY" "Scan" "$C_RESET" "$audit"
  return 0
}

# ar_write_file target rowsfile: replace target's rows, keep header, sort by category then id.
ar_write_file() {
  local target="$1" tmp="$1.tmp.$$"
  { printf '# id\tcategory\tkind\tname\tdescription\turl\n'; sort -t$'\t' -k2,2 -k1,1 "$2"; } > "$tmp" && mv "$tmp" "$target"
}
ar_file_rows() { [ -f "$1" ] && grep -v '^#' "$1" | grep -v '^[[:space:]]*$'; return 0; }

ar_add() {
  local name="$1" url="$2" cat="$3" kind="$4" desc="$5" id="$6" force="$7"
  [ -n "$name" ] || name="$(ar_ask "Name")"
  [ -n "$name" ] || { ar_info "Cancelled."; return 1; }
  [ -n "$url" ] || url="$(ar_ask "Repository URL (https://github.com/owner/repo)")"
  [ -n "$cat" ] || cat="$(ar_pick_category)" || ar_die "Cancelled."
  [ -n "$kind" ] || kind="$(ar_pick_kind)" || ar_die "Cancelled."
  [ -n "$desc" ] || desc="$(ar_ask "One plain sentence: what does it help with?")"
  name="$(ar_clean_field "$name")"; desc="$(ar_clean_field "$desc")"; url="${url%/}"; url="${url%.git}"
  [ -n "$id" ] || id="$(ar_slug "$name")"
  cat="$(printf '%s' "$cat" | tr A-Z a-z)"; kind="$(printf '%s' "$kind" | tr A-Z a-z)"
  ar_valid_id "$id" || ar_die "Invalid id '$id' (use a-z, 0-9 and -)."
  [ -n "$name" ] || ar_die "Name is required."
  ar_valid_url "$url" || ar_die "URL must be https://github.com|gitlab.com|codeberg.org/owner/repo"
  ar_valid_category "$cat" || ar_die "Unknown category '$cat'. See: 4rmory categories"
  ar_valid_kind "$kind" || ar_die "Kind must be one of: $AR_KINDS"
  [ -n "$desc" ] || ar_die "A description is required."
  [ -z "$(ar_get "$id")" ] || ar_die "'$id' already exists. Use: 4rmory edit $id"
  if ar_rows | cut -f6 | grep -qixF "$url"; then ar_die "That URL is already in the catalog."; fi
  # Every new entry is downloaded and scanned before it is saved.
  ar_scan_gate "$id" "$url" "$force" "4rmory add" || return 1
  local target; target="$(ar_target_file)"; ar_init_data
  [ -f "$target" ] || printf '# id\tcategory\tkind\tname\tdescription\turl\n' > "$target"
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$cat" "$kind" "$name" "$desc" "$url" >> "$target"
  ar_ok "Added $name to $(ar_cap "$cat")."
  if ar_is_maintainer; then ar_hint "Share it with everyone: 4rmory publish"
  else ar_hint "Saved to your personal list. Install it: 4rmory install $id"; fi
}

ar_remove() {
  local id="$1" tmp name
  [ -n "$id" ] || ar_die "Usage: 4rmory remove <id>"
  [ -n "$(ar_get "$id")" ] || ar_die "No entry called '$id'."
  name="$(ar_field "$id" 4)"
  ar_confirm "Remove $name?" || { ar_info "Kept."; return 0; }
  ar_init_data; tmp="$(mktemp)"
  if ar_in_file "$id" "$AR_MY"; then
    ar_file_rows "$AR_MY" | awk -F'\t' -v id="$id" '$1!=id' > "$tmp"; ar_write_file "$AR_MY" "$tmp"
  fi
  if ar_official_has "$id"; then
    if ar_is_maintainer; then
      ar_file_rows "$AR_CATALOG" | awk -F'\t' -v id="$id" '$1!=id' > "$tmp"; ar_write_file "$AR_CATALOG" "$tmp"
      ar_hint "Share the change: 4rmory publish"
    else
      printf '%s\n' "$id" >> "$AR_HIDDEN"; ar_hint "Hidden from your list. Bring it back: 4rmory unhide $id"
    fi
  fi
  rm -f "$tmp"; ar_ok "Removed $name."
}

ar_unhide() {
  [ -f "$AR_HIDDEN" ] || ar_die "Nothing is hidden."
  local tmp; tmp="$(mktemp)"; grep -vxF "$1" "$AR_HIDDEN" > "$tmp"; mv "$tmp" "$AR_HIDDEN"; ar_ok "Restored $1."
}

# ar_edit id field value  (field: name|url|category|kind|description)
ar_edit() {
  local id="$1" field="$2" value="$3" force="$4" col row
  [ -n "$id" ] || ar_die "Usage: 4rmory edit <id> [field] [value]"
  row="$(ar_get "$id")"; [ -n "$row" ] || ar_die "No entry called '$id'."
  [ -n "$field" ] || field="$(ar_choose "Field to change" Name Description Category Kind Url)" || ar_die "Cancelled."
  field="$(printf '%s' "$field" | tr A-Z a-z)"
  case "$field" in
    category) col=2 ;; kind) col=3 ;; name) col=4 ;; description|desc) col=5; field=description ;; url) col=6 ;;
    *) ar_die "Field must be name, description, category, kind or url." ;;
  esac
  if [ -z "$value" ]; then
    case "$field" in
      category) value="$(ar_pick_category)" || ar_die "Cancelled." ;;
      kind) value="$(ar_pick_kind)" || ar_die "Cancelled." ;;
      *) value="$(ar_ask "New $field" "$(printf '%s' "$row" | cut -f$col)")" ;;
    esac
  fi
  value="$(ar_clean_field "$value")"
  case "$field" in
    category|kind) value="$(printf '%s' "$value" | tr A-Z a-z)" ;;
  esac
  case "$field" in
    category) ar_valid_category "$value" || ar_die "Unknown category '$value'." ;;
    kind) ar_valid_kind "$value" || ar_die "Kind must be one of: $AR_KINDS" ;;
    url) value="${value%/}"; value="${value%.git}"; ar_valid_url "$value" || ar_die "Invalid URL." ;;
    *) [ -n "$value" ] || ar_die "Value cannot be empty." ;;
  esac
  # A new link is new code: scan it before saving.
  if [ "$field" = url ] && [ "$value" != "$(printf '%s' "$row" | cut -f6)" ]; then
    ar_scan_gate "$id" "$value" "$force" "4rmory edit $id url $value" || return 1
  fi
  local tmp target; tmp="$(mktemp)"; ar_init_data
  if ar_in_file "$id" "$AR_MY" || ! ar_is_maintainer; then target="$AR_MY"; else target="$AR_CATALOG"; fi
  { ar_file_rows "$target" | awk -F'\t' -v id="$id" '$1!=id'
    printf '%s\n' "$row" | awk -F'\t' -v OFS='\t' -v col="$col" -v val="$value" '{$col=val; print}'; } > "$tmp"
  ar_write_file "$target" "$tmp"; rm -f "$tmp"
  ar_ok "Updated the $(ar_cap "$field") of $id."
  [ "$target" = "$AR_CATALOG" ] && ar_hint "Share the change: 4rmory publish"
}

# Export the catalog as Markdown (for READMEs and Obsidian).
ar_export_md() {
  local c
  printf '# 4rmory catalog\n\n> Generated by `4rmory export`. %s entries.\n' "$(ar_rows | wc -l | tr -d ' ')"
  for c in $AR_CATEGORIES; do
    [ -n "$(ar_rows | awk -F'\t' -v c="$c" '$2==c')" ] || continue
    printf '\n## %s\n\n| Name | Kind | What it helps with |\n|---|---|---|\n' "$(ar_cat_label "$c")"
    ar_rows | awk -F'\t' -v c="$c" '$2==c {printf "| [%s](%s) | %s | %s |\n", $4, $6, $3, $5}'
  done
}

# Pickers that show capitalised labels but return the lowercase key.
ar_pick_category() {
  local items=() c sel
  for c in $AR_CATEGORIES; do items+=("$(ar_cap "$c") $C_GREY· $(ar_cat_label "$c")$C_RESET"); done
  sel="$(ar_choose "Category" "${items[@]}")" || return 1
  printf '%s' "${sel%% *}" | tr A-Z a-z
}
ar_pick_kind() {
  local sel; sel="$(ar_choose "Kind" "Skill $C_GREY· Installs into your agent$C_RESET" "Tool $C_GREY· An app or library$C_RESET" "Mcp $C_GREY· An MCP server$C_RESET" "Collection $C_GREY· A list of more skills$C_RESET")" || return 1
  printf '%s' "${sel%% *}" | tr A-Z a-z
}

# Maintainer: commit catalog changes and push them so everyone gets them with `4rmory update`.
ar_publish() {
  ar_is_maintainer || ar_die "Only maintainers publish. Turn it on with: 4rmory maintainer on"
  [ -d "$AR_HOME/.git" ] || ar_die "4rmory is not a git clone: $AR_HOME"
  ar_export_md > "$AR_HOME/CATALOG.md"
  if git -C "$AR_HOME" diff --quiet -- catalog/armory.tsv CATALOG.md; then ar_info "Nothing new to publish."; return 0; fi
  ar_title "Publish"
  git -C "$AR_HOME" --no-pager diff --stat -- catalog/armory.tsv CATALOG.md
  local added; added="$(git -C "$AR_HOME" diff -U0 -- catalog/armory.tsv | grep '^+[^+]' | cut -f4 | paste -sd, - | cut -c1-60)"
  # Re-check every new or changed row (reusing today's scans) before it reaches everyone.
  if ! ar_audit_changed HEAD 1; then
    ar_confirm "Some entries above are malformed or high risk. Publish anyway?" || { ar_info "Not published."; return 1; }
  fi
  ar_confirm "Commit and push these catalog changes to GitHub?" || { ar_info "Not published."; return 0; }
  git -C "$AR_HOME" add catalog/armory.tsv CATALOG.md
  git -C "$AR_HOME" commit -q -m "catalog: update${added:+ ($added)}" || ar_die "Commit failed."
  git -C "$AR_HOME" pull --rebase -q && git -C "$AR_HOME" push -q || ar_die "Push failed. Fix it, then run: git -C $AR_HOME push"
  ar_ok "Published. Everyone gets it with: 4rmory update"
}
