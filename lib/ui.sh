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

# Every page is a centred column AR_PAGE_W wide. AR_M is its left margin (spaces); ar_layout sets it.
AR_PAGE_W=76
AR_M="  "
ar_layout() {
  local p=$(( ($(ar_cols) - AR_PAGE_W) / 2 )); [ "$p" -lt 2 ] && p=2
  AR_M="$(printf '%*s' "$p" '')"
}
# Text width inside the page, for wrapping long lines.
ar_textw() { printf '%s' $((AR_PAGE_W - 4)); }
# Wrap text to the page and indent it: ar_wrap "text" [extra-indent]
ar_wrap() { printf '%s\n' "$1" | fold -s -w "$(( $(ar_textw) - ${#2} ))" | sed "s/^/$AR_M$2/"; }
# Visible width of a string (colour codes do not count).
# Counts characters, not bytes, whatever the locale: UTF-8 continuation bytes (0x80-0xBF) are dropped.
ar_vlen() { printf '%s' "$1" | sed $'s/\033\\[[0-9;]*m//g' | LC_ALL=C tr -d '\200-\277' | wc -c | tr -d ' '; }

ar_rule() { local i line=""; for ((i = 0; i < AR_PAGE_W; i++)); do line="$line─"; done; printf '%s%s%s%s\n' "$AR_M" "$C_GREY" "$line" "$C_RESET"; }
ar_title() { printf '\n%s%s%s▌ %s%s\n\n' "$AR_M" "$C_BOLD" "$C_CYAN" "$1" "$C_RESET"; }
ar_section() { printf '\n%s%s%s%s\n' "$AR_M" "$C_GREY$C_BOLD" "$(printf '%s' "$1" | tr 'a-z' 'A-Z')" "$C_RESET"; }
ar_info()  { printf '%s%s›%s %s\n' "$AR_M" "$C_BLUE" "$C_RESET" "$*"; }
ar_ok()    { printf '%s%s✔%s %s\n' "$AR_M" "$C_GREEN" "$C_RESET" "$*"; }
ar_warn()  { printf '%s%s!%s %s\n' "$AR_M" "$C_YELLOW" "$C_RESET" "$*" >&2; }
ar_err()   { printf '%s%s✖%s %s\n' "$AR_M" "$C_RED" "$C_RESET" "$*" >&2; }
ar_die()   { ar_err "$*"; exit 1; }
ar_hint()  { printf '%s%s  %s%s\n' "$AR_M" "$C_GREY" "$*" "$C_RESET"; }
# A centred one-line note.
ar_center() { local w p; w="$(ar_vlen "$1")"; p=$(( ($(ar_cols) - w) / 2 )); [ "$p" -lt 2 ] && p=2; printf '%*s%s\n' "$p" '' "$1"; }

# ar_grid item... : numbered items in columns of 5. Items fill down a column, then the next column
# starts beside it. Columns that do not fit the window continue in another centred block below.
# A blank line between rows keeps the round badges apart. Prints to stderr when AR_GRID_FD=2.
ar_grid() {
  local n=$# rows=5 max=0 w item cw ncols per b bc bw pad r c idx num pw line out=""
  local items=("$@") vl=()
  for item in "${items[@]}"; do w="$(ar_vlen "$item")"; vl+=("$w"); [ "$w" -gt "$max" ] && max=$w; done
  pw=4; [ "$n" -ge 100 ] && pw=5
  cw=$((pw + 2 + max + 4))
  ncols=$(( (n + rows - 1) / rows ))
  per=$(( ($(ar_cols) - 4 + 4) / cw )); [ "$per" -lt 1 ] && per=1; [ "$per" -gt "$ncols" ] && per=$ncols
  for ((b = 0; b < ncols; b += per)); do
    bc=$(( ncols - b < per ? ncols - b : per ))
    # Every block starts where the first (widest) one does, so the columns line up.
    if [ "$b" -eq 0 ]; then bw=$(( bc * cw - 4 )); pad=$(( ($(ar_cols) - bw) / 2 )); [ "$pad" -lt 2 ] && pad=2; fi
    [ "$b" -gt 0 ] && out="$out"$'\n'
    for ((r = 0; r < rows; r++)); do
      line=""
      for ((c = b; c < b + bc; c++)); do
        idx=$(( c * rows + r )); [ "$idx" -lt "$n" ] || continue
        num=$((idx + 1))
        # ar_pill is 4 wide for 1-2 digits, 5 for 3 digits; pad to the widest badge, then a 2-space gap.
        line="$line$(ar_pill "$num")$(printf '%*s' $(( pw - (${#num} == 3 ? 5 : 4) + 2 )) '')${items[$idx]}"
        [ "$c" -lt $((b + bc - 1)) ] && line="$line$(printf '%*s' $(( max - vl[idx] + 4 )) '')"
      done
      [ -n "$line" ] && out="$out"$'\n'"$(printf '%*s' "$pad" '')$line"$'\n'
    done
  done
  if [ "${AR_GRID_FD:-1}" = 2 ]; then printf '%s' "$out" >&2; else printf '%s' "$out"; fi
}

# Number badges. "round" draws a full-height circle with Nerd Font caps ( 1 );
# "plain" is a bold cyan number for fonts without them. Override: ARMORY_BADGES=round|plain
ar_badge_style() {
  if [ -z "${AR_BADGE_STYLE:-}" ]; then
    case "${ARMORY_BADGES:-}" in
      round|plain) AR_BADGE_STYLE="$ARMORY_BADGES" ;;
      *) if ar_have fc-list && fc-list 2>/dev/null | grep -qi 'nerd font'; then AR_BADGE_STYLE=round; else AR_BADGE_STYLE=plain; fi ;;
    esac
  fi
  printf '%s' "$AR_BADGE_STYLE"
}

ar_pill() {
  local n="$1" pad=""
  [ ${#n} -eq 1 ] && pad=" "
  if [ -z "$C_RESET" ]; then printf '(%s)%s' "$n" "$pad"; return; fi
  if [ "$(ar_badge_style)" = round ]; then
    printf '%s\xee\x82\xb6%s%s%s\xee\x82\xb4%s%s' "$C_BADGE_EDGE" "$C_BADGE" "$n" "$C_BADGE_EDGE" "$C_RESET" "$pad"
  else
    printf ' %s%s%s %s' "$C_CYAN$C_BOLD" "$n" "$C_RESET" "$pad"
  fi
}

ar_is_exit() { case "$1" in [Ee][Xx][Ii][Tt]|[Qq][Uu][Ii][Tt]) return 0 ;; esac; return 1; }

# Leave 4rmory from any depth: stop every helper process under the main
# shell (prompts run inside $(...) and ( ) subshells), then tell it to exit.
ar_exit_now() {
  local self="${BASHPID:-$$}"
  ar_kill_tree() {
    local p
    for p in $(pgrep -P "$1" 2>/dev/null); do
      ar_kill_tree "$p"
      [ "$p" = "$self" ] || kill -PIPE "$p" 2>/dev/null  # PIPE: no "Terminated" noise
    done
  }
  [ -n "${AR_PID:-}" ] && [ "$AR_PID" != "$self" ] || { printf '\n'; ar_ok "See you next time."; exit 0; }
  ar_kill_tree "$AR_PID"
  kill -USR1 "$AR_PID" 2>/dev/null
  exit 0
}

# ar_ask "Question" [default] -> echoes answer. Typing Exit leaves 4rmory.
ar_ask() {
  local q="$1" def="${2:-}" ans
  if [ -n "$def" ]; then printf '\n%s%s❯%s %s %s[%s]%s ' "$AR_M" "$C_CYAN" "$C_RESET" "$q" "$C_GREY" "$def" "$C_RESET" >&2
  else printf '\n%s%s❯%s %s ' "$AR_M" "$C_CYAN" "$C_RESET" "$q" >&2; fi
  IFS= read -r ans || ans=""
  ar_is_exit "$ans" && ar_exit_now
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
  local n
  AR_GRID_FD=2 ar_grid "$@"
  while :; do
    n="$(ar_ask "$prompt ${C_GREY}(1-$#, Enter = ${AR_BACK_LABEL:-Back})${C_RESET}")"
    [ -z "$n" ] && return 1
    case "$n" in *[!0-9]*) ar_warn "Type a number from 1 to $#." ; continue ;; esac
    if [ "$n" -ge 1 ] && [ "$n" -le $# ]; then eval "printf '%s\n' \"\${$n}\""; return 0; fi
    ar_warn "Type a number from 1 to $#."
  done
}
