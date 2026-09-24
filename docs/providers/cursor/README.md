---
description: Track Cursor's monthly included usage, on-demand spend and enterprise team credits, read with the sign-in the Cursor app already stores. Use when setting up Cursor or when it shows nothing, EMPTY or "Session expired".
---

# Cursor

Shows your Cursor plan's included usage for the current billing month, plus on-demand usage and team credits (Enterprise) when they're turned on, and your plan (Free, Pro, Business, Ultra, Enterprise). Everything resets at the end of Cursor's billing cycle.

## Setup

1. Install [Cursor](https://cursor.com) and sign in to it. ClaudeBar reuses that sign-in; there is nothing to configure.
2. Settings → Providers → Cursor: turn it on (it is on by default).

## Gotchas

- **Nothing shows at all** means Cursor's local state database isn't at `~/Library/Application Support/Cursor/User/globalStorage/state.vscdb`. ClaudeBar skips Cursor silently until that file exists, so install Cursor and open it once.
- **"Authentication required. Please log in."** means the database has no sign-in token (you're signed out of Cursor) or cursor.com returned 403. Sign in to Cursor again.
- **"Session expired. Re-authenticate in Cursor settings."** means cursor.com rejected the stored token (HTTP 401). Sign out and back in to Cursor, then refresh ClaudeBar.
- **The numbers are Cursor's own figure.** The percentage is Cursor's `totalPercentUsed`, the same one Cursor shows as "You've used X%", and bonus credits count toward your capacity. Before ClaudeBar 0.4.73, paid plans with bonus credits could show EMPTY.
- **On-demand and team cards only appear when that usage is enabled and has a limit.** Uncapped on-demand spend doesn't get a card.
- **"No usage data found in Cursor response"** means the account reported no plan usage, on-demand limit, team credits or unlimited flag. Some free accounts look like this.

## See also

[design.md](design.md) · [troubleshooting](../../troubleshooting.md)
