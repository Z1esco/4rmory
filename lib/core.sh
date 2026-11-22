# core.sh - paths, settings and small helpers.

AR_VERSION="1.0.0"
AR_CATALOG="${ARMORY_CATALOG:-$AR_HOME/catalog/armory.tsv}"
AR_DATA="${ARMORY_DATA:-${XDG_DATA_HOME:-$HOME/.local/share}/4rmory}"
AR_REPOS="$AR_DATA/repos"
AR_INSTALLED="$AR_DATA/installed.tsv"
AR_REPORTS="$AR_DATA/reports"

# Where each agent looks for skills.
ar_agent_dir() {
  case "$1" in
    claude)   printf '%s' "$HOME/.claude/skills" ;;
    codex)    printf '%s' "$HOME/.codex/skills" ;;
    opencode) printf '%s' "$HOME/.config/opencode/skills" ;;
    agents)   printf '%s' "$HOME/.agents/skills" ;;
    *) return 1 ;;
  esac
}
AR_AGENTS="claude codex opencode agents"

ar_have() { command -v "$1" >/dev/null 2>&1; }

ar_init_data() {
  mkdir -p "$AR_REPOS" "$AR_REPORTS" || ar_die "cannot create $AR_DATA"
  [ -f "$AR_INSTALLED" ] || printf '# id\tagent\tpath\tdate\n' > "$AR_INSTALLED"
}

# Ids are lowercase letters, digits and dashes only. Keeps paths and awk safe.
ar_valid_id() { case "$1" in ''|*[!a-z0-9-]*) return 1 ;; *) return 0 ;; esac; }

ar_valid_url() {
  case "$1" in
    https://github.com/*/*|https://gitlab.com/*/*|https://codeberg.org/*/*) ;;
    *) return 1 ;;
  esac
  case "$1" in *[[:space:]\;\|\&\$\`\'\"\<\>]*) return 1 ;; esac
}

# Strip tabs and newlines so a field can never break the TSV.
ar_clean_field() { printf '%s' "$1" | tr '\t\n\r' '   ' | sed 's/^ *//; s/ *$//'; }

ar_slug() { printf '%s' "$1" | tr 'A-Z' 'a-z' | sed 's/[^a-z0-9]\{1,\}/-/g; s/^-//; s/-$//'; }
