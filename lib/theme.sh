# theme.sh - colours and symbols. Honours NO_COLOR and non-terminals.

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-}" != "dumb" ]; then
  C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'
  C_RED=$'\033[38;5;203m'; C_GREEN=$'\033[38;5;114m'; C_YELLOW=$'\033[38;5;221m'
  C_BLUE=$'\033[38;5;111m'; C_CYAN=$'\033[38;5;80m'; C_MAG=$'\033[38;5;176m'
  C_GREY=$'\033[38;5;245m'
  C_PILL=$'\033[1;38;5;16;48;5;80m'
  AR_GRADIENT="39 45 51 87 123 159"
else
  C_RESET=; C_BOLD=; C_DIM=; C_RED=; C_GREEN=; C_YELLOW=; C_BLUE=; C_CYAN=; C_MAG=; C_GREY=; C_PILL=
  AR_GRADIENT=""
fi

ar_kind_color() {
  case "$1" in
    skill) printf '%s' "$C_GREEN" ;; tool) printf '%s' "$C_BLUE" ;;
    mcp) printf '%s' "$C_MAG" ;; collection) printf '%s' "$C_YELLOW" ;;
    *) printf '%s' "$C_GREY" ;;
  esac
}
