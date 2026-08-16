---
description: Wipe the Night Owl ledger and start the counter over at $0
allowed-tools: Bash
---

The user wants to reset their Night Owl ledger back to $0.

1. First run `"${CLAUDE_PLUGIN_ROOT}/scripts/night-owl.sh" report` and show them what they are about to erase.
2. Ask them to confirm.
3. Only after they confirm, run `"${CLAUDE_PLUGIN_ROOT}/scripts/night-owl.sh" reset`. The old ledger is archived as a .bak file next to it, so nothing is truly lost.
