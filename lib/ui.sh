# ui.sh - banner, messages, prompts and layout.

ar_cols() { local c; c="$(tput cols 2>/dev/null)"; [ -n "$c" ] && [ "$c" -gt 20 ] 2>/dev/null || c=80; printf '%s' "$c"; }

# Capitalise the first letter: "design" -> "Design".
ar_cap() { local f="${1:0:1}"; printf '%s%s' "$(printf '%s' "$f" | tr 'a-z' 'A-Z')" "${1:1}"; }

ar_banner_text() {
  if ar_have figlet && figlet -f slant 4rmory >/dev/null 2>&1; then
    figlet -f slant 4rmory
  else
    cat "$AR_HOME/assets/banner.txt"
  fi
}

ar_banner() {
  [ -n "${AR_QUIET:-}" ] && return 0
  local i=0 line cols pad width=0 colours text tag
  cols="$(ar_cols)"
  text="$(ar_banner_text)"
  while IFS= read -r line; do [ ${#line} -gt "$width" ] && width=${#line}; done <<< "$text"
  pad=$(( (cols - width) / 2 )); [ "$pad" -lt 0 ] && pad=0
  # shellcheck disable=SC2206
  colours=($AR_GRADIENT)
  echo
  while IFS= read -r line; do
    if [ ${#colours[@]} -gt 0 ]; then
      printf '%*s\033[1;38;5;%sm%s%s\n' "$pad" '' "${colours[$((i % ${#colours[@]}))]}" "$line" "$C_RESET"
    else
      printf '%*s%s\n' "$pad" '' "$line"
    fi
    i=$((i + 1))
  done <<< "$text"
  tag="The Armory Of AI Agent Skills  ·  v$AR_VERSION"
  pad=$(( (cols - ${#tag}) / 2 )); [ "$pad" -lt 0 ] && pad=0
  printf '\n%*s%s%s%s\n\n' "$pad" '' "$C_GREY" "$tag" "$C_RESET"
}

ar_rule() { local c i line=""; c="$(ar_cols)"; [ "$c" -gt 100 ] && c=100; for ((i = 0; i < c; i++)); do line="$line─"; done; printf '%s%s%s\n' "$C_GREY" "$line" "$C_RESET"; }
ar_title() { printf '\n%s%s▌ %s%s\n\n' "$C_BOLD" "$C_CYAN" "$1" "$C_RESET"; }
ar_section() { printf '\n  %s%s%s\n' "$C_GREY$C_BOLD" "$(printf '%s' "$1" | tr 'a-z' 'A-Z')" "$C_RESET"; }
ar_info()  { printf '%s›%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
ar_ok()    { printf '%s✔%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
ar_warn()  { printf '%s!%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
ar_err()   { printf '%s✖%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
ar_die()   { ar_err "$*"; exit 1; }
ar_hint()  { printf '%s  %s%s\n' "$C_GREY" "$*" "$C_RESET"; }

# A number badge: coloured pill, or [ 1] without colour.
ar_pill() {
  if [ -n "$C_RESET" ]; then printf '%s %2s %s' "$C_PILL" "$1" "$C_RESET"
  else printf '[%2s]' "$1"; fi
}

# ar_ask "Question" [default] -> echoes answer
ar_ask() {
  local q="$1" def="${2:-}" ans
  if [ -n "$def" ]; then printf '\n%s❯%s %s %s[%s]%s ' "$C_CYAN" "$C_RESET" "$q" "$C_GREY" "$def" "$C_RESET" >&2
  else printf '\n%s❯%s %s ' "$C_CYAN" "$C_RESET" "$q" >&2; fi
  IFS= read -r ans || { AR_EOF=1; ans=""; }
  printf '%s' "${ans:-$def}"
}

# ar_confirm "Question" -> 0 on yes. AR_YES=1 answers yes.
ar_confirm() {
  [ -n "${AR_YES:-}" ] && return 0
  local ans; ans="$(ar_ask "$1 (y/N)")"
  case "$ans" in y|Y|yes|Yes|YES) return 0 ;; *) return 1 ;; esac
}

# ar_choose "Prompt" item... -> echoes the chosen item.
# Blank input means "go back" (returns 1). Invalid input asks again.
ar_choose() {
  local prompt="$1"; shift
  if ar_have fzf && [ -t 0 ] && [ -z "${AR_NO_FZF:-}" ]; then
    printf '%s\n' "$@" | fzf --height=60% --reverse --border=rounded --prompt="$prompt › " --ansi || return 1
    return 0
  fi
  local i=1 item n
  echo >&2
  for item in "$@"; do printf '  %s  %s\n' "$(ar_pill "$i")" "$item" >&2; i=$((i + 1)); done
  while :; do
    n="$(ar_ask "$prompt ${C_GREY}(1-$#, Enter = ${AR_BACK_LABEL:-Back})${C_RESET}")"
    [ -z "$n" ] && return 1
    case "$n" in *[!0-9]*) ar_warn "Type a number from 1 to $#." ; continue ;; esac
    if [ "$n" -ge 1 ] && [ "$n" -le $# ]; then eval "printf '%s\n' \"\${$n}\""; return 0; fi
    ar_warn "Type a number from 1 to $#."
  done
}
