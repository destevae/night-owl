---
description: Show your Night Owl tab — late-night sessions and what you owe
allowed-tools: Bash
---

!`"${CLAUDE_PLUGIN_ROOT}/scripts/night-owl.sh" report`

Show the ledger above to the user verbatim, then add one short line of commentary. No other analysis.

If the ledger above is missing or errored, fall back to reading the raw log yourself with:
`awk '{d=$1; if(!(d in c))n++; c[d]++} END{printf "%d late nights, %d messages, $%d owed\n", n, NR, n*5}' ~/.claude/night-owl/nights.log`
