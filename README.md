# 🦉 night-owl

A Claude Code plugin that notices when you're coding at night and charges you for it.

Every message you send to Claude Code between **12:30 AM and 5 AM** local time gets
logged. The first message of each night adds **$5** to your tab — one charge per
night, no matter how many messages you send before sunrise.

```
 🦉  NIGHT OWL LEDGER
 ---------------------------------------------
   Owed          $15.00
   Late nights   3  (at $5.00 each)
   Messages      9 sent inside the window
   First time    2026-08-02
   Most recent   2026-08-15
   Worst night   2026-08-15  (5 messages, 12:33 AM - 4:52 AM)

   Recent nights
     2026-08-15    5 msgs   12:33 AM - 4:52 AM
     2026-08-09    1 msg    2:03 AM
     2026-08-02    3 msgs   12:41 AM - 3:22 AM
```

## Install

Type these inside Claude Code (desktop app, terminal, or IDE — anywhere you can
send a message):

```
/plugin marketplace add YOUR-GITHUB-USERNAME/night-owl
/plugin install night-owl@night-owl-marketplace
```

If you don't have SSH keys set up with GitHub, use the full HTTPS URL instead —
the `owner/repo` shorthand clones over SSH by default:

```
/plugin marketplace add https://github.com/YOUR-GITHUB-USERNAME/night-owl.git
```

Then restart Claude Code, or run `/reload-plugins`.

## Checking your tab

| Where | What to run |
| --- | --- |
| In Claude Code | `/night-owl:tab` |
| In Claude Code | Just ask: "how much do I owe the night owl?" |
| Any terminal | `~/.claude/night-owl/nights.log` is plain text — see below |

The plugin's `bin/` directory is on the PATH of Claude Code's Bash tool while the
plugin is enabled, so Claude can run `night-owl report` for you on request.

From your own shell, without needing the plugin path:

```bash
awk '{if(!($1 in c))n++; c[$1]++} END{printf "$%d owed across %d late nights (%d messages)\n", n*5, n, NR}' ~/.claude/night-owl/nights.log
```

The first late-night message each night also pops a one-line notice in your session:

> 🦉 Night owl tax: +$5.00 for 2026-08-15. You now owe $25.00 across 5 late nights.

After that the plugin stays quiet for the rest of the night.

## Commands

| Command | What it does |
| --- | --- |
| `/night-owl:tab` | Show the ledger and what you owe |
| `/night-owl:reset` | Archive the ledger and start over at $0 |

## How it works

A `UserPromptSubmit` hook runs `scripts/night-owl.sh track` every time you send a
message. The script checks the local clock, and if you're inside the window it
appends a line to a plain-text ledger:

```
~/.claude/night-owl/nights.log

2026-08-15 00:33:00
2026-08-15 01:01:00
```

Money owed is just `number of distinct dates in that file x $5`, so the ledger is
easy to audit, edit, or delete by hand. The hook never blocks or delays your
prompt — it exits 0 no matter what happens, and outside the window it does
nothing at all.

## Config

Set these as environment variables (for example in `~/.claude/settings.json` under
`"env"`):

| Variable | Default | Meaning |
| --- | --- | --- |
| `NIGHT_OWL_START` | `0030` | Window opens, HHMM local time |
| `NIGHT_OWL_END` | `0500` | Window closes, HHMM local time |
| `NIGHT_OWL_RATE` | `5` | Dollars per offending night |
| `NIGHT_OWL_DATA_DIR` | `~/.claude/night-owl` | Where the ledger lives |
| `NIGHT_OWL_QUIET` | unset | Set to `1` to track silently, no in-chat notice |

Windows that wrap past midnight work too — `NIGHT_OWL_START=2300` with
`NIGHT_OWL_END=0500` bills you for anything after 11 PM.

## Development

Test without installing:

```bash
claude --plugin-dir /path/to/night-owl
```

Validate the manifests — run this from inside the `night-owl` directory:

```
/plugin validate .
```

## Publishing

This repo is its own marketplace: `.claude-plugin/marketplace.json` lists one
plugin whose `source` is `./`, the repo root. Push it to GitHub and it's
installable.

```bash
cd night-owl
git init
git add -A
git commit -m "night-owl: bill yourself $5 a night for late-night Claude Code"
gh repo create night-owl --public --source=. --push
```

Shipping an update: **bump `version` in `.claude-plugin/plugin.json`**, then commit
and push. Claude Code only pulls a new copy when that version changes. Users pick
it up with:

```
/plugin marketplace update night-owl-marketplace
/plugin update night-owl@night-owl-marketplace
```
