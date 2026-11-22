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

ar_rows() { grep -v '^#' "$AR_CATALOG" | grep -v '^[[:space:]]*$'; }

# ar_get id -> the full row, or nothing.
ar_get() { ar_rows | awk -F'\t' -v id="$1" '$1==id {print; exit}'; }
ar_field() { ar_get "$1" | cut -f"$2"; }

# Print rows as a neat list.
ar_print_rows() {
  local id cat kind name desc url width n=0 kc
  width=$(( $(ar_cols) - 34 )); [ "$width" -lt 30 ] && width=30
  while IFS=$'\t' read -r id cat kind name desc url; do
    kc="$(ar_kind_color "$kind")"
    [ ${#desc} -gt "$width" ] && desc="${desc:0:$((width - 1))}…"
    printf '  %s%-28s%s %s%-10s%s %s\n' "$C_BOLD" "$id" "$C_RESET" "$kc" "$kind" "$C_RESET" "$C_GREY$cat$C_RESET"
    printf '  %s%s%s\n' "$C_DIM" "$desc" "$C_RESET"
    n=$((n + 1))
  done
  [ "$n" -eq 0 ] && ar_warn "Nothing found."
  [ "$n" -gt 0 ] && printf '\n%s  %d result(s) · see one with: 4rmory info <id>%s\n' "$C_GREY" "$n" "$C_RESET"
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

ar_categories() {
  ar_title "Categories"
  local c count
  for c in $AR_CATEGORIES; do
    count="$(ar_rows | awk -F'\t' -v c="$c" '$2==c' | wc -l | tr -d ' ')"
    [ "$count" -eq 0 ] && continue
    printf '  %s%-13s%s %s%3s%s  %s\n' "$C_CYAN$C_BOLD" "$c" "$C_RESET" "$C_YELLOW" "$count" "$C_RESET" "$(ar_cat_label "$c")"
  done
  ar_hint "Browse one with: 4rmory list <category>"
}

ar_info_card() {
  local row id cat kind name desc url
  row="$(ar_get "$1")"; [ -n "$row" ] || ar_die "No entry called '$1'. Try: 4rmory search $1"
  IFS=$'\t' read -r id cat kind name desc url <<< "$row"
  ar_title "$name"
  printf '  %-10s %s\n' "id" "$C_BOLD$id$C_RESET"
  printf '  %-10s %s\n' "kind" "$(ar_kind_color "$kind")$kind$C_RESET"
  printf '  %-10s %s (%s)\n' "category" "$cat" "$(ar_cat_label "$cat")"
  printf '  %-10s %s\n' "link" "$C_BLUE$url$C_RESET"
  printf '  %-10s %s\n' "about" "$desc"
  if ar_is_installed "$id"; then printf '  %-10s %s\n' "status" "${C_GREEN}installed${C_RESET}"
  else printf '  %-10s %s\n' "status" "${C_GREY}not installed · 4rmory install $id${C_RESET}"; fi
  local audit; audit="$(ar_audit_status "$id")"
  [ -n "$audit" ] && printf '  %-10s %s\n' "audit" "$audit"
  return 0
}

ar_write_catalog() {
  # $1 = file with new rows (no header). Keeps the header and sorts by category then id.
  local tmp="$AR_CATALOG.tmp.$$"
  { grep '^#' "$AR_CATALOG"; sort -t$'\t' -k2,2 -k1,1 "$1"; } > "$tmp" && mv "$tmp" "$AR_CATALOG"
}

ar_add() {
  local name="$1" url="$2" cat="$3" kind="$4" desc="$5" id="$6"
  [ -n "$name" ] || name="$(ar_ask "Name")"
  [ -n "$url" ] || url="$(ar_ask "Repository URL (https://github.com/owner/repo)")"
  [ -n "$cat" ] || cat="$(ar_choose "Category" $AR_CATEGORIES)" || ar_die "Cancelled."
  [ -n "$kind" ] || kind="$(ar_choose "Kind" $AR_KINDS)" || ar_die "Cancelled."
  [ -n "$desc" ] || desc="$(ar_ask "One plain sentence: what does it help with?")"
  name="$(ar_clean_field "$name")"; desc="$(ar_clean_field "$desc")"; url="${url%/}"; url="${url%.git}"
  [ -n "$id" ] || id="$(ar_slug "$name")"
  ar_valid_id "$id" || ar_die "Invalid id '$id' (use a-z, 0-9 and -)."
  [ -n "$name" ] || ar_die "Name is required."
  ar_valid_url "$url" || ar_die "URL must be https://github.com|gitlab.com|codeberg.org/owner/repo"
  ar_valid_category "$cat" || ar_die "Unknown category '$cat'. See: 4rmory categories"
  ar_valid_kind "$kind" || ar_die "Kind must be one of: $AR_KINDS"
  [ -n "$desc" ] || ar_die "A description is required."
  [ -z "$(ar_get "$id")" ] || ar_die "'$id' already exists. Use: 4rmory edit $id"
  if ar_rows | cut -f6 | grep -qixF "$url"; then ar_die "That URL is already in the catalog."; fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$cat" "$kind" "$name" "$desc" "$url" >> "$AR_CATALOG"
  ar_ok "Added $id to $cat."
  ar_hint "Check it before sharing: 4rmory audit $id"
}

ar_remove() {
  local id="$1"
  [ -n "$id" ] || ar_die "Usage: 4rmory remove <id>"
  [ -n "$(ar_get "$id")" ] || ar_die "No entry called '$id'."
  ar_confirm "Remove '$id' from the catalog?" || { ar_info "Kept."; return 0; }
  local tmp; tmp="$(mktemp)"
  ar_rows | awk -F'\t' -v id="$id" '$1!=id' > "$tmp"; ar_write_catalog "$tmp"; rm -f "$tmp"
  ar_ok "Removed $id."
}

# ar_edit id field value  (field: name|url|category|kind|description)
ar_edit() {
  local id="$1" field="$2" value="$3" col row
  [ -n "$id" ] || ar_die "Usage: 4rmory edit <id> [field] [value]"
  row="$(ar_get "$id")"; [ -n "$row" ] || ar_die "No entry called '$id'."
  [ -n "$field" ] || field="$(ar_choose "Field to change" name description category kind url)" || ar_die "Cancelled."
  case "$field" in
    category) col=2 ;; kind) col=3 ;; name) col=4 ;; description|desc) col=5; field=description ;; url) col=6 ;;
    *) ar_die "Field must be name, description, category, kind or url." ;;
  esac
  if [ -z "$value" ]; then
    case "$field" in
      category) value="$(ar_choose "Category" $AR_CATEGORIES)" || ar_die "Cancelled." ;;
      kind) value="$(ar_choose "Kind" $AR_KINDS)" || ar_die "Cancelled." ;;
      *) value="$(ar_ask "New $field" "$(printf '%s' "$row" | cut -f$col)")" ;;
    esac
  fi
  value="$(ar_clean_field "$value")"
  case "$field" in
    category) ar_valid_category "$value" || ar_die "Unknown category '$value'." ;;
    kind) ar_valid_kind "$value" || ar_die "Kind must be one of: $AR_KINDS" ;;
    url) value="${value%/}"; ar_valid_url "$value" || ar_die "Invalid URL." ;;
    *) [ -n "$value" ] || ar_die "Value cannot be empty." ;;
  esac
  local tmp; tmp="$(mktemp)"
  ar_rows | awk -F'\t' -v OFS='\t' -v id="$id" -v col="$col" -v val="$value" '$1==id {$col=val} {print}' > "$tmp"
  ar_write_catalog "$tmp"; rm -f "$tmp"
  ar_ok "Updated $field of $id."
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
