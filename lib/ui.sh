# ui.sh - banner, messages, prompts and layout.

ar_cols() { local c; c="$(tput cols 2>/dev/null)"; [ -n "$c" ] && [ "$c" -gt 20 ] 2>/dev/null || c=80; printf '%s' "$c"; }

# Print text centred on the terminal, line by line.
ar_center() {
  local cols line pad
  cols="$(ar_cols)"
  while IFS= read -r line; do
    pad=$(( (cols - ${#line}) / 2 )); [ "$pad" -lt 0 ] && pad=0
    printf '%*s%s\n' "$pad" '' "$line"
  done
}

ar_banner_text() {
  if ar_have figlet && figlet -f slant 4rmory >/dev/null 2>&1; then
    figlet -f slant 4rmory
  else
    cat "$AR_HOME/assets/banner.txt"
  fi
}

ar_banner() {
  [ -n "${AR_QUIET:-}" ] && return 0
  local i=0 line cols pad width=0 colours
  cols="$(ar_cols)"
  local text; text="$(ar_banner_text)"
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
  local tag="the armory of AI agent skills  ·  v$AR_VERSION"
  pad=$(( (cols - ${#tag}) / 2 )); [ "$pad" -lt 0 ] && pad=0
  printf '\n%*s%s%s%s\n\n' "$pad" '' "$C_GREY" "$tag" "$C_RESET"
}

ar_rule() { local c; c="$(ar_cols)"; [ "$c" -gt 100 ] && c=100; printf '%s' "$C_GREY"; printf '%*s' "$c" '' | tr ' ' '─'; printf '%s\n' "$C_RESET"; }
ar_title() { printf '\n%s%s▌ %s%s\n' "$C_BOLD" "$C_CYAN" "$1" "$C_RESET"; }
ar_info()  { printf '%s›%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
ar_ok()    { printf '%s✔%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
ar_warn()  { printf '%s!%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
ar_err()   { printf '%s✖%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
ar_die()   { ar_err "$*"; exit 1; }
ar_hint()  { printf '%s  %s%s\n' "$C_GREY" "$*" "$C_RESET"; }

# ar_ask "Question" [default] -> echoes answer
ar_ask() {
  local q="$1" def="${2:-}" ans
  if [ -n "$def" ]; then printf '%s?%s %s %s[%s]%s ' "$C_CYAN" "$C_RESET" "$q" "$C_GREY" "$def" "$C_RESET" >&2
  else printf '%s?%s %s ' "$C_CYAN" "$C_RESET" "$q" >&2; fi
  IFS= read -r ans || ans=""
  printf '%s' "${ans:-$def}"
}

# ar_confirm "Question" -> 0 on yes. AR_YES=1 answers yes.
ar_confirm() {
  [ -n "${AR_YES:-}" ] && return 0
  local ans; ans="$(ar_ask "$1 (y/N)")"
  case "$ans" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}

# ar_choose "Prompt" item... -> echoes the chosen item (fzf when available).
ar_choose() {
  local prompt="$1"; shift
  if ar_have fzf && [ -t 0 ]; then
    printf '%s\n' "$@" | fzf --height=50% --reverse --prompt="$prompt › " --ansi || return 1
    return 0
  fi
  local i=1 item n
  for item in "$@"; do printf '  %s%2d%s  %s\n' "$C_CYAN" "$i" "$C_RESET" "$item" >&2; i=$((i + 1)); done
  n="$(ar_ask "$prompt (number, blank to cancel)")"
  case "$n" in ''|*[!0-9]*) return 1 ;; esac
  [ "$n" -ge 1 ] && [ "$n" -le $# ] || return 1
  eval "printf '%s\n' \"\${$n}\""
}
