# cli.sh - commands, help and the interactive menu.

ar_help() {
  ar_banner
  local c="$C_CYAN" r="$C_RESET" b="$C_BOLD" g="$C_GREY"
  ar_help_text | sed "s/^/$AR_M/"
}
ar_help_text() {
  local c="$C_CYAN" r="$C_RESET" b="$C_BOLD" g="$C_GREY"
  cat <<HELP
${b}Usage${r}   4rmory ${c}<command>${r}      ${g}Just type 4rmory for the easy menu.${r}

${b}Getting Started${r}
  1. ${c}4rmory doctor${r}           Check that everything needed is installed
  2. ${c}4rmory setup${r}            Pick your agent and areas; skills are scanned and installed
  3. Restart your agent      It loads the new skills
  4. ${c}4rmory update${r}           Run any time to get newly added skills

${b}Find${r}
  ${c}search${r} <words>          Search everything        ${g}-c <category>  -k <kind>${r}
  ${c}list${r} [category]         Show all, or one category
  ${c}categories${r}              Show the categories
  ${c}info${r} <id>               Short card about one skill or tool
  ${c}details${r} <id>            Its project page: summary, sections, pictures, videos
  ${c}open${r} <id>               Open its GitHub page in your browser

${b}Install${r}
  ${c}setup${r}                   Guided install for your agent
  ${c}install${r} <id>            Scan, then install       ${g}--agent claude|codex|opencode|agents${r}
  ${c}install -c${r} <category>   Scan and install every skill in a category
  ${c}uninstall${r} <id>          Remove it again
  ${c}installed${r}               What you have installed
  ${c}update${r}                  Get newly added skills and update installed ones

${b}Your List${r}
  ${c}add${r}                     Add a skill or tool      ${g}--name --url -c -k -d  (scanned first)${r}
  ${c}edit${r} <id>               Change an entry          ${g}a new link is scanned first${r}
  ${c}remove${r} <id>             Remove (or hide) an entry
  ${c}unhide${r} <id>             Bring back a hidden entry
  ${c}export${r}                  Print the catalog as Markdown

${b}Safety${r}
  ${c}audit${r} <id>              Scan for malware         ${g}--installed  --all-skills  --changed  <folder>${r}
  ${c}doctor${r}                  Check this machine

${b}Maintainers${r}
  ${c}maintainer${r} on|off       Your add/edit/remove change the shared catalog
  ${c}publish${r}                 Push catalog changes so everyone gets them on update

${g}Options: -y answers yes · -q hides the banner · NO_COLOR=1 turns colour off${r}
HELP
}

ar_doctor() {
  ar_title "Doctor"
  local t
  for t in git awk python3 curl fzf figlet chafa skillspector skill-scanner; do
    if ar_have "$t"; then ar_ok "$(ar_cap "$t")"; else
      case "$t" in
        git|awk) ar_err "$(ar_cap "$t") is required" ;;
        python3) ar_warn "Python3 (needed for scanner reports and project details)" ;;
        curl) ar_warn "Curl (optional: project details for skills you have not installed)" ;;
        chafa) ar_warn "Chafa (optional: see project pictures in the terminal; viu also works)" ;;
        fzf) ar_warn "Fzf (optional: arrow-key menus) → install with your package manager" ;;
        figlet) ar_warn "Figlet (optional: live banner) → install with your package manager" ;;
        skillspector) ar_warn "SkillSpector (recommended) → uv tool install git+https://github.com/NVIDIA/skillspector.git" ;;
        skill-scanner) ar_warn "Skill-scanner (recommended) → uv tool install cisco-ai-skill-scanner" ;;
      esac
    fi
  done
  echo
  ar_info "Catalog: $(ar_rows | wc -l | tr -d ' ') entries · $AR_CATALOG"
  ar_info "Your data: $AR_DATA"
  if ar_is_maintainer; then ar_info "Maintainer mode: On"; else ar_info "Maintainer mode: Off"; fi
}

ar_maintainer() {
  ar_init_data
  case "${1:-}" in
    on) : > "$AR_DATA/maintainer"; ar_ok "Maintainer mode on. Add/edit/remove now change the shared catalog."; ar_hint "Share changes with: 4rmory publish" ;;
    off) rm -f "$AR_DATA/maintainer"; ar_ok "Maintainer mode off. Changes go to your personal list." ;;
    *) if ar_is_maintainer; then ar_info "Maintainer mode: On"; else ar_info "Maintainer mode: Off"; fi; ar_hint "Change it: 4rmory maintainer on|off" ;;
  esac
}

# Show rows with numbers, let the user open one, then offer actions.
# A numbered list of entries. Type a number to open one, A to install every skill in the list,
# or a range like 1-3,5 to install several at once.
ar_pick_and_open() {
  local rows="$1" n sel id picks skills
  [ -n "$rows" ] || { ar_warn "Nothing found. Try fewer or different words."; return 0; }
  printf '%s\n' "$rows" | ar_grid_rows
  n="$(printf '%s\n' "$rows" | wc -l | tr -d ' ')"
  skills="$(printf '%s\n' "$rows" | awk -F'\t' '$3=="skill"' | wc -l | tr -d ' ')"
  ar_center "${C_GREY}Number = see one · ${C_RESET}${C_BOLD}A${C_RESET}${C_GREY} = install all $skills skills · ${C_RESET}${C_BOLD}1-3,5${C_RESET}${C_GREY} = install a range${C_RESET}"
  while :; do
    sel="$(ar_ask "Your choice ${C_GREY}(1-$n, A, range, Enter = Back)${C_RESET}")"
    sel="${sel// /}"
    [ -z "$sel" ] && return 0
    case "$sel" in
      [Aa]|[Aa][Ll][Ll])
        [ "$skills" -gt 0 ] || { ar_warn "No agent skills in this list (only tools or collections). Open one to see it."; continue; }
        # shellcheck disable=SC2046
        ar_install_many $(printf '%s\n' "$rows" | awk -F'\t' '$3=="skill" {print $1}')
        return 0 ;;
      *[!0-9]*)
        picks="$(ar_parse_picks "$sel" "$n")" || { ar_warn "Type a number, A, or a range like 1-3,5 (from 1 to $n)."; continue; }
        # shellcheck disable=SC2046
        ar_install_many $(printf '%s\n' "$picks" | while IFS= read -r i; do printf '%s\n' "$rows" | sed -n "${i}p" | cut -f1; done)
        return 0 ;;
    esac
    [ "$sel" -ge 1 ] && [ "$sel" -le "$n" ] || { ar_warn "Type a number from 1 to $n."; continue; }
    id="$(printf '%s\n' "$rows" | sed -n "${sel}p" | cut -f1)"
    ar_open_entry "$id"
    return 0
  done
}

ar_open_entry() {
  local id="$1" act
  ar_info_card "$id"
  while :; do
    if ar_is_installed "$id"; then
      act="$(ar_choose "What next" "Show Details" "Open On GitHub" "Scan it again" "Uninstall" "Edit")" || return 0
    else
      act="$(ar_choose "What next" "Show Details" "Open On GitHub" "Install" "Scan it first" "Edit" "Remove")" || return 0
    fi
    case "$act" in
      "Show Details") ar_details "$id"; continue ;;
      "Open On GitHub") ar_open_url "$(ar_field "$id" 6)"; continue ;;
    esac
    break
  done
  case "$act" in
    Install) (ar_install "$id") ;;
    "Scan it first"|"Scan it again") (ar_audit "$id") ;;
    Uninstall) (ar_uninstall "$id") ;;
    Edit) (ar_edit "$id") ;;
    Remove) (ar_remove "$id") ;;
  esac
}

# The menu is drawn as one block, centred under the banner. AR_MENU_W is the block's visible width:
# badge (4) + gap (2) + label (26) + space (1) + longest description (38).
AR_MENU_W=71
ar_menu_pad() { local p=$(( ($(ar_cols) - AR_MENU_W) / 2 )); [ "$p" -lt 2 ] && p=2; printf '%s' "$p"; }

# One numbered row, with a blank line before it so the round badges never touch.
ar_menu_item() {
  printf '\n%*s%s  %s%-26s%s %s%s%s\n' "$AR_MPAD" '' "$(ar_pill "$1")" "$C_BOLD" "$2" "$C_RESET" "$C_GREY" "$3" "$C_RESET"
}
# Section title; the next row's leading newline ends its line, so there is no gap under it.
ar_menu_section() { printf '\n%*s%s%s%s' "$AR_MPAD" '' "$C_GREY$C_BOLD" "$(printf '%s' "$1" | tr 'a-z' 'A-Z')" "$C_RESET"; }

ar_menu_draw() {
  local pending="$1" hint="Type a number and press Enter · Type Exit anytime to leave" hp
  ar_layout
  AR_MPAD="$(ar_menu_pad)"
  ar_menu_section "Find"
  ar_menu_item 1 "Search" "Find skills and tools by keyword"
  ar_menu_item 2 "Browse Categories" "Look through one area at a time"
  ar_menu_section "Install"
  ar_menu_item 3 "Guided Setup" "Pick your agent and areas, install all"
  ar_menu_item 4 "My Installed Skills" "See what you have"
  if [ -n "$pending" ] && [ "$pending" -gt 0 ] 2>/dev/null; then
    ar_menu_item 5 "Update" "${C_YELLOW}★ New skills are available!${C_RESET}"
  else
    ar_menu_item 5 "Update" "Get newly added skills"
  fi
  ar_menu_section "Your List"
  ar_menu_item 6 "Add A Skill Or Tool" "Save a new one to the list"
  ar_menu_item 7 "Edit Or Remove" "Change an entry"
  ar_menu_section "Safety & Help"
  ar_menu_item 8 "Scan For Malware" "Check a skill or a folder"
  ar_menu_item 9 "Doctor" "Check your setup"
  ar_menu_item 10 "Help" "All commands"
  printf '\n'
  ar_menu_item 0 "Exit" ""
  hp=$(( ($(ar_cols) - ${#hint}) / 2 )); [ "$hp" -lt 2 ] && hp=2
  printf '\n\n%*s%s%s%s\n' "$hp" '' "$C_GREY" "$hint" "$C_RESET"
}

ar_menu() {
  ar_banner
  local choice q pending
  pending="$(ar_pending_updates)"
  local draw=1
  while :; do
    [ -n "$draw" ] && ar_menu_draw "$pending"
    draw=1
    printf '\n%*s%s❯%s Choose %s(0-10)%s ' "${AR_MPAD:-2}" '' "$C_CYAN" "$C_RESET" "$C_GREY" "$C_RESET"
    IFS= read -r choice || { echo; return 0; }
    case "$choice" in
      "") draw=""; continue ;;
      1) q="$(ar_ask "Search for")"; [ -n "$q" ] && ar_pick_and_open "$(ar_filter "$q" "" "")" ;;
      2) q="$(ar_pick_category)" && { ar_title "$(ar_cap "$q") · $(ar_cat_label "$q")"; ar_pick_and_open "$(ar_filter "" "$q" "")"; } ;;
      3) (ar_setup) ;;
      4) ar_installed ;;
      5) (ar_update); pending=0 ;;
      6) ar_title "Add A Skill Or Tool"; (ar_add) ;;
      7) q="$(ar_ask "Name or id of the entry")"
         [ -n "$q" ] && ar_pick_and_open "$(ar_filter "$q" "" "")" ;;
      8) q="$(ar_ask "Id or folder to scan")"; [ -n "$q" ] && (ar_audit "$q") ;;
      9) ar_doctor ;;
      10) ar_help ;;
      0|q|Q) echo; ar_ok "See you next time."; return 0 ;;
      *) if ar_is_exit "$choice"; then echo; ar_ok "See you next time."; return 0; fi
         ar_warn "Type a number from the menu (0 or Exit to leave)."; draw=""; continue ;;
    esac
    printf '\n'; ar_rule
  done
}

ar_main() {
  AR_BADGE_STYLE="$(ar_badge_style)"
  AR_PID=$$
  ar_layout
  trap 'printf "\n"; ar_ok "See you next time."; exit 0' USR1
  local args=() a
  for a in "$@"; do
    case "$a" in -y|--yes) AR_YES=1 ;; -q|--quiet) AR_QUIET=1 ;; *) args+=("$a") ;; esac
  done
  set -- "${args[@]+"${args[@]}"}"
  [ -r "$AR_CATALOG" ] || ar_die "Catalog not found: $AR_CATALOG"
  local cmd="${1:-}"; [ $# -gt 0 ] && shift
  case "$cmd" in
    "") if [ -t 0 ]; then ar_menu; else ar_help; fi ;;
    menu) ar_menu ;;
    search|s|find)
      local q="" c="" k=""
      while [ $# -gt 0 ]; do
        case "$1" in -c|--category) c="$(printf '%s' "$2" | tr A-Z a-z)"; shift ;; -k|--kind) k="$(printf '%s' "$2" | tr A-Z a-z)"; shift ;; *) q="$q $1" ;; esac; shift
      done
      [ -n "$c" ] && { ar_valid_category "$c" || ar_die "Unknown category '$c'. See: 4rmory categories"; }
      ar_title "Results For:${q:- Everything}"; ar_filter "$q" "$c" "$k" | ar_print_rows ;;
    list|ls)
      if [ -n "${1:-}" ]; then
        local lc; lc="$(printf '%s' "$1" | tr A-Z a-z)"
        ar_valid_category "$lc" || ar_die "Unknown category '$1'. See: 4rmory categories"
        ar_title "$(ar_cap "$lc") · $(ar_cat_label "$lc")"; ar_filter "" "$lc" "" | ar_print_rows
      else ar_title "Everything"; ar_rows | sort -t$'\t' -k2,2 -k1,1 | ar_print_rows; fi ;;
    categories|cats) ar_categories ;;
    info|show|i) [ -n "${1:-}" ] || ar_die "Usage: 4rmory info <id>"; ar_info_card "$1" ;;
    install|in)
      if [ "${1:-}" = "-c" ] || [ "${1:-}" = "--category" ]; then
        local ic; ic="$(printf '%s' "${2:-}" | tr A-Z a-z)"
        ar_valid_category "$ic" || ar_die "Usage: 4rmory install -c <category>. See: 4rmory categories"
        shift 2
        local ia=""; while [ $# -gt 0 ]; do case "$1" in --agent|-a) ia="$2"; shift ;; esac; shift; done
        # shellcheck disable=SC2046
        AR_AGENT="$ia" ar_install_many $(ar_rows | awk -F'\t' -v c="$ic" '$2==c && $3=="skill" {print $1}')
      else ar_install "$@"; fi ;;
    details|about) [ -n "${1:-}" ] || ar_die "Usage: 4rmory details <id>"; ar_details "$1" ;;
    open) [ -n "${1:-}" ] || ar_die "Usage: 4rmory open <id>"; ar_open_url "$(ar_field "$1" 6)" ;;
    uninstall|rm) ar_uninstall "${1:-}" ;;
    installed) ar_installed ;;
    update|up) ar_update ;;
    setup) ar_banner; ar_setup ;;
    add)
      local n="" u="" c="" k="" d="" id="" f=""
      while [ $# -gt 0 ]; do
        case "$1" in
          --name) n="$2"; shift ;; --url) u="$2"; shift ;; -c|--category) c="$2"; shift ;;
          -k|--kind) k="$2"; shift ;; -d|--desc|--description) d="$2"; shift ;; --id) id="$2"; shift ;;
          --force) f=1 ;;
          *) ar_die "Unknown option $1" ;;
        esac; shift
      done
      ar_add "$n" "$u" "$c" "$k" "$d" "$id" "$f" ;;
    edit|modify)
      local ea=() f=""
      for a in "$@"; do case "$a" in --force) f=1 ;; *) ea+=("$a") ;; esac; done
      ar_edit "${ea[0]:-}" "${ea[1]:-}" "${ea[2]:-}" "$f" ;;
    remove|delete) ar_remove "${1:-}" ;;
    unhide) [ -n "${1:-}" ] || ar_die "Usage: 4rmory unhide <id>"; ar_unhide "$1" ;;
    export) ar_export_md ;;
    publish) ar_publish ;;
    maintainer) ar_maintainer "${1:-}" ;;
    audit|scan) ar_audit "${1:-}" "${2:-}" ;;
    doctor) ar_doctor ;;
    help|-h|--help) ar_help ;;
    version|-v|--version) echo "4rmory $AR_VERSION" ;;
    *) ar_err "Unknown command '$cmd'."; ar_hint "See all commands: 4rmory help"; exit 1 ;;
  esac
}
