# Snippets (Bash, portable to 3.2)

Prefix `x_` = your tool's namespace. Translate the ideas to other languages:
Python (`rich`/`prompt_toolkit`, `signal`), Node (`readline`, `process.on`), Go/Rust (`os/signal`).

## Entry point (follows symlinks, loads modules)

```bash
#!/usr/bin/env bash
set -o pipefail
x_resolve_self() {
  local src="${BASH_SOURCE[0]}" dir
  while [ -L "$src" ]; do
    dir="$(cd -P "$(dirname "$src")" && pwd)"; src="$(readlink "$src")"
    case "$src" in /*) ;; *) src="$dir/$src" ;; esac
  done
  cd -P "$(dirname "$src")" && pwd
}
X_HOME="$(x_resolve_self)"
for m in core theme ui data install cli; do . "$X_HOME/lib/$m.sh"; done
x_main "$@"
```

## Theme (NO_COLOR + non-TTY safe)

```bash
if [ -z "${NO_COLOR:-}" ] && [ -t 1 ]; then
  C_RESET=$'\033[0m' C_BOLD=$'\033[1m' C_GREY=$'\033[38;5;245m' C_CYAN=$'\033[38;5;80m'
  C_GREEN=$'\033[38;5;114m' C_YELLOW=$'\033[38;5;221m' C_RED=$'\033[38;5;203m' C_BLUE=$'\033[38;5;75m'
  C_BADGE=$'\033[1;38;5;16;48;5;80m' C_BADGE_EDGE=$'\033[0;38;5;80m'
  X_GRADIENT="51 45 39 33 69 105"
else
  C_RESET= C_BOLD= C_GREY= C_CYAN= C_GREEN= C_YELLOW= C_RED= C_BLUE= C_BADGE= C_BADGE_EDGE= X_GRADIENT=
fi
```

## Messages, capitalise, rule

```bash
x_cols() { local c; c="$(tput cols 2>/dev/null)"; [ "${c:-0}" -gt 20 ] 2>/dev/null || c=80; printf '%s' "$c"; }
x_cap()  { local f="${1:0:1}"; printf '%s%s' "$(printf '%s' "$f" | tr 'a-z' 'A-Z')" "${1:1}"; }
x_rule() { local c i l=""; c="$(x_cols)"; [ "$c" -gt 100 ] && c=100; for ((i=0;i<c;i++)); do l="$l─"; done; printf '%s%s%s\n' "$C_GREY" "$l" "$C_RESET"; }
x_info() { printf '%s›%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
x_ok()   { printf '%s✔%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
x_warn() { printf '%s!%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
x_err()  { printf '%s✖%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
```

## Centred gradient banner with fallback

```bash
x_banner() {
  local text line w=0 pad i=0 cols; cols="$(x_cols)"
  if command -v figlet >/dev/null && figlet -f slant NAME >/dev/null 2>&1; then text="$(figlet -f slant NAME)"
  else text="$(cat "$X_HOME/assets/banner.txt")"; fi
  while IFS= read -r line; do [ ${#line} -gt $w ] && w=${#line}; done <<< "$text"
  pad=$(( (cols - w) / 2 )); [ $pad -lt 0 ] && pad=0
  local g=($X_GRADIENT)
  while IFS= read -r line; do
    if [ ${#g[@]} -gt 0 ]; then printf '%*s\033[1;38;5;%sm%s%s\n' $pad '' "${g[$((i % ${#g[@]}))]}" "$line" "$C_RESET"
    else printf '%*s%s\n' $pad '' "$line"; fi; i=$((i+1))
  done <<< "$text"
}
```
Generate `assets/banner.txt` once with `pyfiglet -f slant NAME` so systems without figlet still look right.

## Round number badges (Nerd Font) with fallbacks

```bash
x_badge_style() {   # call once in main: X_BADGE_STYLE="$(x_badge_style)"
  case "${TOOL_BADGES:-}" in round|plain) printf '%s' "$TOOL_BADGES"; return ;; esac
  if command -v fc-list >/dev/null && fc-list 2>/dev/null | grep -qi 'nerd font'; then printf round; else printf plain; fi
}
x_pill() {
  local n="$1" pad=""; [ ${#n} -eq 1 ] && pad=" "
  [ -z "$C_RESET" ] && { printf '(%s)%s' "$n" "$pad"; return; }
  if [ "$X_BADGE_STYLE" = round ]; then   # U+E0B6  n  U+E0B4
    printf '%s\xee\x82\xb6%s%s%s\xee\x82\xb4%s%s' "$C_BADGE_EDGE" "$C_BADGE" "$n" "$C_BADGE_EDGE" "$C_RESET" "$pad"
  else printf ' %s%s%s %s' "$C_CYAN$C_BOLD" "$n" "$C_RESET" "$pad"; fi
}
```

## Exit from any depth (prompts run inside `$(...)` subshells)

```bash
x_is_exit() { case "$1" in [Ee][Xx][Ii][Tt]|[Qq][Uu][Ii][Tt]) return 0;; esac; return 1; }
x_exit_now() {
  local self="${BASHPID:-$$}"
  x_kill_tree() { local p; for p in $(pgrep -P "$1" 2>/dev/null); do x_kill_tree "$p"; [ "$p" = "$self" ] || kill -PIPE "$p" 2>/dev/null; done; }
  if [ -z "${X_PID:-}" ] || [ "$X_PID" = "$self" ]; then printf '\n'; x_ok "See you next time."; exit 0; fi
  x_kill_tree "$X_PID"; kill -USR1 "$X_PID" 2>/dev/null; exit 0
}
# in main:
X_PID=$$
trap 'printf "\n"; x_ok "See you next time."; exit 0' USR1
trap 'printf "\n"; exit 130' INT
```
SIGPIPE, not SIGTERM: bash prints `Terminated` for TERM-killed jobs.

## Prompt, confirm, chooser

```bash
x_ask() {   # x_ask "Question" [default]  -> echoes answer
  local q="$1" def="${2:-}" a
  printf '\n%s❯%s %s%s ' "$C_CYAN" "$C_RESET" "$q" "${def:+ $C_GREY[$def]$C_RESET}" >&2
  IFS= read -r a || a=""
  x_is_exit "$a" && x_exit_now
  printf '%s' "${a:-$def}"
}
x_confirm() { [ -n "${X_YES:-}" ] && return 0; case "$(x_ask "$1 (y/N)")" in y|Y|yes|Yes|YES) return 0;; esac; return 1; }

x_choose() {   # x_choose "Prompt" item...  -> echoes item; blank = back (return 1)
  local prompt="$1"; shift
  if command -v fzf >/dev/null && [ -t 0 ]; then printf '%s\n' "$@" | fzf --height=60% --reverse --border=rounded --prompt="$prompt › " --ansi; return; fi
  local i=1 it n; echo >&2
  for it in "$@"; do printf '  %s  %s\n' "$(x_pill $i)" "$it" >&2; i=$((i+1)); done
  while :; do
    n="$(x_ask "$prompt ${C_GREY}(1-$#, Enter = ${X_BACK_LABEL:-Back})${C_RESET}")"
    [ -z "$n" ] && return 1
    case "$n" in *[!0-9]*) x_warn "Type a number from 1 to $#."; continue;; esac
    [ "$n" -ge 1 ] && [ "$n" -le $# ] && { eval "printf '%s\n' \"\${$n}\""; return 0; }
    x_warn "Type a number from 1 to $#."
  done
}
```

## Menu loop: blank = re-prompt, no redraw

```bash
x_menu() {
  local draw=1 c
  while :; do
    if [ $draw = 1 ]; then clear 2>/dev/null; x_banner; x_menu_draw; fi
    draw=0
    IFS= read -r -p "$(printf '%s❯%s ' "$C_CYAN" "$C_RESET")" c || { echo; return 0; }
    case "$c" in
      "") continue ;;
      0) x_ok "See you next time."; return 0 ;;
      *) x_is_exit "$c" && { x_ok "See you next time."; return 0; } ;;
    esac
    case "$c" in
      1) x_search ;; 2) x_browse ;; # ...
      *) x_warn "Type a number from the menu."; continue ;;
    esac
    draw=1; x_ask "Press Enter to go back" >/dev/null
  done
}
x_menu_draw() {
  printf '\n  %sFIND%s\n' "$C_GREY$C_BOLD" "$C_RESET"
  printf '  %s  Search\n' "$(x_pill 1)"
  printf '  %s  Browse by category\n' "$(x_pill 2)"
  # ... more sections ...
  printf '\n  %s  Exit\n' "$(x_pill 0)"
  printf '\n  %sType a number and press Enter · Type Exit anytime to leave%s\n' "$C_GREY" "$C_RESET"
}
```

## Layered data: shared + personal overlay + hidden

```bash
# rows: id<TAB>... ; personal overrides shared by id; hidden ids dropped
x_rows() {
  awk -F'\t' 'FNR==1{f++} f==1{h[$1]=1;next} f==2{if(!($1 in h)){seen[$1]=1;print};next} f==3{if(!($1 in h)&&!($1 in seen))print}' \
    "${X_HIDDEN:-/dev/null}" "${X_MY:-/dev/null}" "$X_HOME/data/catalog.tsv"
}
```
(Create the overlay files empty on first run so awk's file counter stays aligned.)

## Self-update + throttled "new available" notice

```bash
x_update() {
  local before after; before="$(cut -f1 "$X_HOME/data/catalog.tsv" | sort)"
  git -C "$X_HOME" pull --rebase --autostash -q || { x_err "Update failed. Check your connection."; return 1; }
  after="$(cut -f1 "$X_HOME/data/catalog.tsv" | sort)"
  comm -13 <(echo "$before") <(echo "$after") | sed 's/^/  + /'
}
x_pending_updates() {   # prints count of upstream commits touching the data file
  local stamp="$X_DATA/.last-fetch" now; now=$(date +%s)
  if [ ! -f "$stamp" ] || [ $((now - $(cat "$stamp"))) -gt 21600 ]; then
    timeout 5 git -C "$X_HOME" fetch -q 2>/dev/null; echo "$now" > "$stamp"
  fi
  git -C "$X_HOME" rev-list --count 'HEAD..@{u}' -- data/catalog.tsv 2>/dev/null || echo 0
}
```

## Input validation

```bash
x_valid_id()  { case "$1" in ""|*[!a-z0-9-]*) return 1;; esac; }
x_valid_url() { case "$1" in https://github.com/*|https://gitlab.com/*|https://codeberg.org/*) ;; *) return 1;; esac
                case "$1" in *[\;\`\$\|\&\<\>\ \"\']*) return 1;; esac; }
x_clean_field() { printf '%s' "$1" | tr '\t\n\r' '   '; }
```

## Two-scanner verdict

```
each scanner -> clean | warn | danger   (use its own recommendation field when it has one)
final = danger  if every scanner that ran says danger
        warn    if any says warn/danger
        clean   otherwise
built-in grep only decides when no scanner is installed
danger -> block unless --force ; warn -> "Install anyway? (y/N)"
```

## Test harness

```bash
# scripted walk incl. blank + junk input
printf '\n\nxyz\n1\nfoo\n\n0\n' | NO_COLOR=1 ./tool

# exit from inside nested prompts
printf '1\nfoo\nexit\n' | ./tool; echo "rc=$?"

# real TTY bytes
python3 - <<'PY'
import pty, os, sys
out=b''
pid, fd = pty.fork()
if pid == 0: os.execvp('./tool', ['./tool'])
os.write(fd, b'0\n')
try:
    while True:
        d=os.read(fd, 4096)
        if not d: break
        out+=d
except OSError: pass
sys.stdout.write(repr(out[:2000]))
PY

# self-update e2e with a local bare remote
tmp=$(mktemp -d); git clone -q --bare . "$tmp/origin.git"
git clone -q "$tmp/origin.git" "$tmp/a"; git clone -q "$tmp/origin.git" "$tmp/b"
# change data in a, commit, push; then in b: X_HOME=$tmp/b ./tool update

# secret sweep (files + history)
git log -p --all | grep -nEi 'api[_-]?key|secret|token|password|BEGIN .*PRIVATE|@gmail|/home/[a-z]+' | head
```
