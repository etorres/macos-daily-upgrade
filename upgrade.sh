#!/usr/bin/env bash
#
# Daily macOS upgrade routine: Homebrew formulae, casks and mise-managed tools.
#
# Usage:
#   ./upgrade.sh              run every step
#   ./upgrade.sh --dry-run    print what would run, change nothing
#   ./upgrade.sh --skip-casks skip the (slow) greedy cask upgrade
#   ./upgrade.sh --quiet      only write to the log file, not the terminal
#
set -uo pipefail

BREW=/opt/homebrew/bin/brew
MISE=/opt/homebrew/bin/mise

LOG_DIR="${UPGRADE_LOG_DIR:-$HOME/.local/state/upgrade}"
LOG_FILE="$LOG_DIR/upgrade-$(date +%Y-%m-%d).log"
LOG_KEEP_DAYS=30

DRY_RUN=0
SKIP_CASKS=0
QUIET=0

for arg in "$@"; do
  case "$arg" in
    --dry-run)    DRY_RUN=1 ;;
    --skip-casks) SKIP_CASKS=1 ;;
    --quiet)      QUIET=1 ;;
    -h|--help)    sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)            echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

mkdir -p "$LOG_DIR"

# Everything below goes to the log; the terminal too unless --quiet.
if [[ $QUIET -eq 1 ]]; then
  exec >>"$LOG_FILE" 2>&1
else
  exec > >(tee -a "$LOG_FILE") 2>&1
fi

if [[ -t 1 ]]; then
  BOLD=$'\033[1m'; RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RESET=$'\033[0m'
else
  BOLD=""; RED=""; GREEN=""; YELLOW=""; RESET=""
fi

FAILED=()
WARNED=()

# run <label> <fatal|warn> <command...>
#   fatal -> a failure aborts the run (nothing downstream would make sense)
#   warn  -> a failure is recorded and the run continues
run() {
  local label="$1" severity="$2"; shift 2
  echo
  echo "${BOLD}==> $label${RESET}   ($*)"

  if [[ $DRY_RUN -eq 1 ]]; then
    echo "    [dry-run] skipped"
    return 0
  fi

  local start=$SECONDS
  local code=0
  "$@" || code=$?

  if [[ $code -eq 0 ]]; then
    echo "${GREEN}    ok${RESET} ($((SECONDS - start))s)"
    return 0
  fi

  if [[ "$severity" == fatal ]]; then
    echo "${RED}    failed (exit $code) — aborting${RESET}"
    FAILED+=("$label")
    finish
    exit 1
  fi
  echo "${YELLOW}    failed (exit $code) — continuing${RESET}"
  WARNED+=("$label")
  return 0
}

finish() {
  echo
  echo "${BOLD}==> Summary${RESET}"
  if [[ ${#FAILED[@]} -eq 0 && ${#WARNED[@]} -eq 0 ]]; then
    echo "${GREEN}    all steps completed${RESET}"
  else
    local s
    for s in "${FAILED[@]:-}";  do [[ -n "$s" ]] && echo "${RED}    failed:  $s${RESET}"; done
    for s in "${WARNED[@]:-}";  do [[ -n "$s" ]] && echo "${YELLOW}    warned:  $s${RESET}"; done
  fi
  echo "    log: $LOG_FILE"
}

command -v "$BREW" >/dev/null || { echo "${RED}brew not found at $BREW${RESET}"; exit 1; }

echo "${BOLD}macOS upgrade — $(date '+%Y-%m-%d %H:%M:%S')${RESET}"
[[ $DRY_RUN -eq 1 ]] && echo "${YELLOW}dry run: no changes will be made${RESET}"

# Fetching the latest formulae must succeed; upgrading stale metadata is pointless.
run "brew update"            fatal "$BREW" update

run "brew upgrade"           warn  "$BREW" upgrade

if [[ $SKIP_CASKS -eq 1 ]]; then
  echo; echo "${BOLD}==> brew upgrade --cask --greedy${RESET}"; echo "    skipped (--skip-casks)"
else
  # --greedy also upgrades casks that auto-update themselves; some casks prompt
  # for the admin password, so this step can block waiting on input.
  run "brew upgrade --cask --greedy" warn "$BREW" upgrade --cask --greedy
fi

run "brew autoremove"        warn  "$BREW" autoremove

# brew doctor exits non-zero for purely advisory warnings — never fatal.
run "brew doctor"            warn  "$BREW" doctor

run "brew cleanup"           warn  "$BREW" cleanup --prune=all

if [[ -x "$MISE" ]]; then
  run "mise upgrade"         warn  "$MISE" upgrade
else
  echo; echo "${YELLOW}==> mise not found at $MISE — skipped${RESET}"
fi

# Keep the log directory from growing without bound.
if [[ $DRY_RUN -eq 0 ]]; then
  find "$LOG_DIR" -name 'upgrade-*.log' -type f -mtime "+$LOG_KEEP_DAYS" -delete 2>/dev/null
fi

finish
[[ ${#FAILED[@]} -gt 0 ]] && exit 1
exit 0
