# cli.sh - commands, help and the interactive menu.

ar_help() {
  ar_banner
  cat <<HELP
${C_BOLD}Usage${C_RESET}  4rmory ${C_CYAN}<command>${C_RESET} [options]      ${C_GREY}(no command opens the menu)${C_RESET}

${C_BOLD}Find${C_RESET}
  ${C_CYAN}search${C_RESET} <words> [-c category] [-k kind]   Search names and descriptions
  ${C_CYAN}list${C_RESET} [category]                          Show everything, or one category
  ${C_CYAN}categories${C_RESET}                               Show all categories
  ${C_CYAN}info${C_RESET} <id>                                Details about one entry

${C_BOLD}Install${C_RESET}
  ${C_CYAN}setup${C_RESET}                                    Guided install for your agent
  ${C_CYAN}install${C_RESET} <id> [--agent claude] [--all]    Scan, then install a skill or tool
  ${C_CYAN}uninstall${C_RESET} <id>                           Remove an installed entry
  ${C_CYAN}installed${C_RESET}                                What you have installed
  ${C_CYAN}update${C_RESET}                                   Update 4rmory and everything installed

${C_BOLD}Manage the catalog${C_RESET}
  ${C_CYAN}add${C_RESET} [--name N --url U -c cat -k kind -d desc]   Add a new skill or tool
  ${C_CYAN}edit${C_RESET} <id> [field] [value]                Change name, description, category, kind or url
  ${C_CYAN}remove${C_RESET} <id>                              Delete an entry
  ${C_CYAN}export${C_RESET}                                   Print the catalog as Markdown

${C_BOLD}Safety${C_RESET}
  ${C_CYAN}audit${C_RESET} <id|--installed|--all-skills|folder>   Scan for malware and risky code
  ${C_CYAN}doctor${C_RESET}                                   Check what is installed on this machine

  Kinds: ${C_GREEN}skill${C_RESET} ${C_BLUE}tool${C_RESET} ${C_MAG}mcp${C_RESET} ${C_YELLOW}collection${C_RESET}   ·   -y answers yes   ·   NO_COLOR=1 turns colour off
  Agents: $AR_AGENTS
HELP
}

ar_doctor() {
  ar_title "Doctor"
  local t
  for t in git awk fzf figlet skillspector skill-scanner; do
    if ar_have "$t"; then ar_ok "$t"; else
      case "$t" in
        git|awk) ar_err "$t (required)" ;;
        fzf) ar_warn "fzf (optional: nicer menus)  → install with your package manager" ;;
        figlet) ar_warn "figlet (optional: live banner) → install with your package manager" ;;
        skillspector) ar_warn "skillspector (recommended) → pipx install git+https://github.com/NVIDIA/skillspector.git" ;;
        skill-scanner) ar_warn "skill-scanner (recommended) → pipx install cisco-ai-skill-scanner" ;;
      esac
    fi
  done
  ar_info "Catalog: $AR_CATALOG ($(ar_rows | wc -l | tr -d ' ') entries)"
  ar_info "Data:    $AR_DATA"
}

ar_menu() {
  ar_banner
  local choice q
  while :; do
    choice="$(ar_choose "What do you want to do" \
      "Search" "Browse a category" "Guided setup" "Install by id" "Installed" \
      "Audit (scan for malware)" "Add a skill or tool" "Edit an entry" "Remove an entry" \
      "Update everything" "Doctor" "Help" "Quit")" || return 0
    echo
    case "$choice" in
      Search) q="$(ar_ask "Search for")"; [ -n "$q" ] && ar_filter "$q" "" "" | ar_print_rows ;;
      "Browse a category") q="$(ar_choose "Category" $AR_CATEGORIES)" && ar_filter "" "$q" "" | ar_print_rows ;;
      "Guided setup") ar_setup ;;
      "Install by id") q="$(ar_ask "Id to install")"; [ -n "$q" ] && (ar_install "$q") ;;
      Installed) ar_installed ;;
      "Audit (scan for malware)") q="$(ar_ask "Id or folder to scan")"; [ -n "$q" ] && (ar_audit "$q") ;;
      "Add a skill or tool") (ar_add) ;;
      "Edit an entry") q="$(ar_ask "Id to edit")"; [ -n "$q" ] && (ar_edit "$q") ;;
      "Remove an entry") q="$(ar_ask "Id to remove")"; [ -n "$q" ] && (ar_remove "$q") ;;
      "Update everything") ar_update ;;
      Doctor) ar_doctor ;;
      Help) ar_help ;;
      Quit|"") return 0 ;;
    esac
    echo; ar_rule
  done
}

ar_main() {
  local args=() a
  for a in "$@"; do
    case "$a" in -y|--yes) AR_YES=1 ;; -q|--quiet) AR_QUIET=1 ;; *) args+=("$a") ;; esac
  done
  set -- "${args[@]+"${args[@]}"}"
  [ -r "$AR_CATALOG" ] || ar_die "Catalog not found: $AR_CATALOG"
  local cmd="${1:-}"; [ $# -gt 0 ] && shift
  case "$cmd" in
    "") if [ -t 0 ]; then ar_menu; else ar_help; fi ;;
    search|s|find)
      local q="" c="" k=""
      while [ $# -gt 0 ]; do
        case "$1" in -c|--category) c="$2"; shift ;; -k|--kind) k="$2"; shift ;; *) q="$q $1" ;; esac; shift
      done
      [ -n "$c" ] && { ar_valid_category "$c" || ar_die "Unknown category '$c'."; }
      ar_title "Results for:${q:- everything}"; ar_filter "$q" "$c" "$k" | ar_print_rows ;;
    list|ls)
      if [ -n "${1:-}" ]; then ar_valid_category "$1" || ar_die "Unknown category '$1'. See: 4rmory categories"
        ar_title "$(ar_cat_label "$1")"; ar_filter "" "$1" "" | ar_print_rows
      else ar_title "Everything"; ar_rows | sort -t$'\t' -k2,2 -k1,1 | ar_print_rows; fi ;;
    categories|cats|c) ar_categories ;;
    info|show|i) [ -n "${1:-}" ] || ar_die "Usage: 4rmory info <id>"; ar_info_card "$1" ;;
    install|in) ar_install "$@" ;;
    uninstall|rm) ar_uninstall "${1:-}" ;;
    installed) ar_installed ;;
    update|up) ar_update ;;
    setup) ar_setup ;;
    add)
      local n="" u="" c="" k="" d="" id=""
      while [ $# -gt 0 ]; do
        case "$1" in
          --name) n="$2"; shift ;; --url) u="$2"; shift ;; -c|--category) c="$2"; shift ;;
          -k|--kind) k="$2"; shift ;; -d|--desc|--description) d="$2"; shift ;; --id) id="$2"; shift ;;
          *) ar_die "Unknown option $1" ;;
        esac; shift
      done
      ar_add "$n" "$u" "$c" "$k" "$d" "$id" ;;
    edit|modify) ar_edit "${1:-}" "${2:-}" "${3:-}" ;;
    remove|delete) ar_remove "${1:-}" ;;
    export) ar_export_md ;;
    audit|scan) ar_audit "${1:-}" ;;
    doctor) ar_doctor ;;
    help|-h|--help) ar_help ;;
    version|-v|--version) echo "4rmory $AR_VERSION" ;;
    *) ar_err "Unknown command '$cmd'."; ar_hint "See all commands: 4rmory help"; exit 1 ;;
  esac
}
