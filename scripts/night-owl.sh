#!/usr/bin/env bash
# night-owl — tracks Claude Code usage in the small hours and bills you for it.
#
#   night-owl.sh track    run by the UserPromptSubmit hook on every message
#   night-owl.sh report   print the ledger
#   night-owl.sh reset    archive the ledger and start over
#
# Config (env vars, all optional):
#   NIGHT_OWL_START     window opens, HHMM local time   (default 0030)
#   NIGHT_OWL_END       window closes, HHMM local time  (default 0500)
#   NIGHT_OWL_RATE      dollars per offending night     (default 5)
#   NIGHT_OWL_DATA_DIR  where the ledger lives          (default ~/.claude/night-owl)
#   NIGHT_OWL_QUIET     set to 1 to suppress the in-chat notice

set -u

START="${NIGHT_OWL_START:-0030}"
END="${NIGHT_OWL_END:-0500}"
RATE="${NIGHT_OWL_RATE:-5}"
DATA_DIR="${NIGHT_OWL_DATA_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/night-owl}"
LOG="$DATA_DIR/nights.log"

# Never, ever get in the way of the user's prompt.
trap 'exit 0' ERR

# --- helpers ----------------------------------------------------------------

num() { printf '%d' "$((10#${1#0000}))" 2>/dev/null || printf '0'; }

in_window() {
  local now s e
  now=$(num "$1"); s=$(num "$START"); e=$(num "$END")
  if [ "$s" -lt "$e" ]; then
    [ "$now" -ge "$s" ] && [ "$now" -lt "$e" ]
  else
    # window wraps past midnight, e.g. 2300 -> 0500
    [ "$now" -ge "$s" ] || [ "$now" -lt "$e" ]
  fi
}

# Aggregate the log. $1 = "summary" or "nights".
stats() {
  [ -s "$LOG" ] || return 1
  awk -v rate="$RATE" -v mode="$1" '
    function ampm(t,   h, m, sfx, hh) {
      h = substr(t, 1, 2) + 0; m = substr(t, 4, 2)
      sfx = (h < 12) ? "AM" : "PM"; hh = h % 12; if (hh == 0) hh = 12
      return hh ":" m " " sfx
    }
    NF >= 2 {
      d = $1; t = $2
      if (!(d in cnt)) order[++n] = d
      cnt[d]++; total++
      if (mn[d] == "" || t < mn[d]) mn[d] = t
      if (mx[d] == "" || t > mx[d]) mx[d] = t
      if (cnt[d] > worstc) { worstc = cnt[d]; worst = d }
    }
    END {
      if (n == 0) exit 1
      if (mode == "summary") {
        printf "%d\t%d\t%.2f\t%s\t%s\t%s\t%d\t%s\t%s\n", \
          n, total, n * rate, order[1], order[n], worst, worstc, \
          ampm(mn[worst]), ampm(mx[worst])
      } else {
        for (i = n; i > 0 && i > n - 10; i--) {
          d = order[i]
          printf "     %s   %2d %s   %s%s\n", d, cnt[d], \
            (cnt[d] == 1 ? "msg " : "msgs"), ampm(mn[d]), \
            (mn[d] == mx[d] ? "" : " - " ampm(mx[d]))
        }
      }
    }
  ' "$LOG"
}

money() { printf '$%.2f' "$1"; }

# --- commands ---------------------------------------------------------------

do_track() {
  local now today stamp first summary nights owed
  now="${NIGHT_OWL_NOW:-$(date +%H%M)}"
  today="${NIGHT_OWL_TODAY:-$(date +%Y-%m-%d)}"
  stamp="${NIGHT_OWL_TIME:-$(date +%H:%M:%S)}"

  in_window "$now" || exit 0

  mkdir -p "$DATA_DIR" 2>/dev/null || exit 0
  touch "$LOG" 2>/dev/null || exit 0

  # One charge per calendar day, no matter how many messages.
  first=0
  grep -q "^$today " "$LOG" 2>/dev/null || first=1

  printf '%s %s\n' "$today" "$stamp" >> "$LOG" 2>/dev/null || exit 0

  [ "$first" = 1 ] || exit 0
  [ "${NIGHT_OWL_QUIET:-0}" = 1 ] && exit 0

  summary=$(stats summary) || exit 0
  nights=$(printf '%s' "$summary" | cut -f1)
  owed=$(printf '%s' "$summary" | cut -f3)

  # systemMessage shows the notice to the user without polluting the transcript.
  printf '{"systemMessage":"%s","suppressOutput":true}\n' \
    "$(printf '\xf0\x9f\xa6\x89 Night owl tax: +%s for %s. You now owe %s across %s late night%s.' \
      "$(money "$RATE")" "$today" "$(money "$owed")" "$nights" \
      "$([ "$nights" = 1 ] || printf s)")"
  exit 0
}

do_report() {
  local summary nights msgs owed first last worst worstc wfrom wto
  printf '\n \xf0\x9f\xa6\x89  NIGHT OWL LEDGER\n'
  printf ' ---------------------------------------------\n'

  if ! summary=$(stats summary); then
    printf '   Owed          %s\n' "$(money 0)"
    printf '   Late nights   0\n\n'
    printf '   Nothing on the books. Window is %s - %s local time. \xf0\x9f\x8c\x99\n\n' \
      "$(printf '%s' "$START" | sed 's/\(..\)\(..\)/\1:\2/')" \
      "$(printf '%s' "$END" | sed 's/\(..\)\(..\)/\1:\2/')"
    return 0
  fi

  IFS=$'\t' read -r nights msgs owed first last worst worstc wfrom wto <<< "$summary"

  printf '   Owed          %s\n' "$(money "$owed")"
  printf '   Late nights   %s  (at %s each)\n' "$nights" "$(money "$RATE")"
  printf '   Messages      %s sent inside the window\n' "$msgs"
  printf '   First time    %s\n' "$first"
  printf '   Most recent   %s\n' "$last"
  printf '   Worst night   %s  (%s messages, %s - %s)\n' "$worst" "$worstc" "$wfrom" "$wto"
  printf '\n   Recent nights\n'
  stats nights
  printf '\n   Ledger: %s\n\n' "$LOG"
}

do_reset() {
  local bak
  if [ -s "$LOG" ]; then
    bak="$LOG.$(date +%Y%m%d%H%M%S).bak"
    mv "$LOG" "$bak"
    printf 'Ledger reset. Previous ledger archived at:\n  %s\n' "$bak"
  else
    printf 'Nothing to reset - the ledger is already empty.\n'
  fi
}

case "${1:-track}" in
  track)  do_track ;;
  report) do_report ;;
  reset)  do_reset ;;
  *)      printf 'usage: night-owl.sh [track|report|reset]\n' >&2; exit 0 ;;
esac
