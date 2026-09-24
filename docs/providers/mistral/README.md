---
description: Show today's and yesterday's Mistral Vibe cost and token totals, read from Vibe's local session logs. No API key needed. Use when setting up Mistral or when its card is empty.
---

# Mistral

Shows how much you spent and how many tokens you used in **Mistral Vibe** today, next to yesterday. ClaudeBar has no source for Mistral's rate limits or plan quota, so there's no percentage or reset time, only daily spend and tokens.

## Setup

1. Use Mistral Vibe at least once, so it has written session logs to `~/.vibe/logs/session/`.
2. Settings → Providers → Mistral → turn it on. It is off by default.
3. Keep Settings → General → **Daily Usage Cards** on (the default). Mistral's numbers only appear in those cards.

No key, no network access and no permission prompts: ClaudeBar only reads the local log files.

## Gotchas

- **Only Vibe is counted.** Le Chat and the Mistral API used from other tools (OpenCode and the like) don't write Vibe logs, so their usage is missing. For account-wide spend, use the Mistral console.
- **Empty card with Daily Usage Cards off.** With the setting off, Mistral shows no numbers at all, because it has no quota bars.
- **ClaudeBar treats Mistral as unavailable until `~/.vibe/logs/session/` exists**, so it stays empty on a Mac where Vibe was never run.
- **A session counts on the day it started.** A session that begins before midnight and runs past it is counted entirely in the earlier day.
- **Cost is Vibe's own number** (`session_cost` in each session's `meta.json`). ClaudeBar doesn't apply its own pricing, so if Vibe's cost is off, ClaudeBar's is too.
- Session folders whose `meta.json` is missing or unreadable are skipped without an error.

## See also

[troubleshooting](../../troubleshooting.md) · [#209](https://github.com/tddworks/ClaudeBar/pull/209), an open PR that would add Vibe plan usage from Mistral's web API with a chat.mistral.ai session cookie
