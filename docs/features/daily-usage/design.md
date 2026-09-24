# Daily Usage Token/Cost Deduplication — Calculation Logic Design

**Status:** Implemented
**Date:** 2026-06-09
**Issue:** [#207](https://github.com/tddworks/ClaudeBar/issues/207) — Daily Usage cost & token cards overcount ~4×
**Affected code:** `Sources/Infrastructure/Claude/SessionJSONLParser.swift`, `Sources/Infrastructure/Claude/ClaudeDailyUsageAnalyzer.swift`

---

## 1. Problem

The Daily Usage cards (Cost Usage / Token Usage) sum **every** usage-bearing line in
`~/.claude/projects/**/*.jsonl`. Claude Code writes the **same** `message.usage` block
multiple times:

1. **Streaming** — one assistant line per content block as the response streams
   (thinking / text / tool_use). Each repeats the full `usage`; `output_tokens` grows
   across the snapshots until the final, complete value.
2. **Parallel tool calls** — multiple assistant messages in one turn share the same
   `message.id` with byte-identical `usage`.
3. **Resume / branch** — when a session is resumed or branched, prior entries are copied
   into the new session file, so identical lines recur across different `.jsonl` files.

Today's pipeline (`SessionJSONLParser` → `ClaudeDailyUsageAnalyzer.aggregate`) creates one
`TokenUsageRecord` per line and adds them all together, with **no deduplication**. Result:
the displayed cost and token totals are inflated.

### Measured impact (this machine, all history)

| Metric | Value |
|---|---|
| distinct `(message.id, requestId)` groups | 12,297 |
| groups appearing more than once | 6,780 (55%) |
| duplicate groups with **byte-identical** usage | 6,437 |
| duplicate groups with **varying** `output_tokens` (streaming) | 343 |
| naive sum (current app) | 5,357,322,061 tokens |
| deduped (last-wins) | 3,027,710,023 tokens → **1.77× reduction** |

Cache-heavy days reach ~4× (per the issue), because duplication multiplies the
already-dominant cache-read figure.

### Confirmed against Anthropic's own guidance

[Agent SDK — Track cost and usage](https://code.claude.com/docs/en/agent-sdk/cost-tracking):

> "When Claude uses multiple tools in one turn, all messages in that turn share the same
> ID, so **deduplicate by ID to avoid double-counting**."
>
> "**Use the highest value: the final message in a group typically contains the accurate
> total.**" (output-token discrepancy resolution)

The doc's own example keeps a `seenIds` set and counts each message ID once — exactly the
step we are missing.

---

## 2. Goals & Non-Goals

**Goals**
- Eliminate over-counting so Cost/Token cards align with Claude Code's own `/cost`.
- Handle all three duplication sources (streaming, parallel tools, resume/branch copies).
- Preserve correctness for the streaming case: never under-count `output_tokens`.
- Keep the change localized to the parse → aggregate path; no UI/domain-model churn.

**Non-Goals**
- Authoritative billing. The cost figure remains a **client-side estimate** built from a
  local price table; it can drift from the real bill (pricing changes, unknown models).
  This matches the SDK's own warning. We target parity with `/cost`, not the invoice.
- Changing the 2-day scan window, working-time estimation, or per-model pricing tables.

---

## 3. Deduplication Key

**Chosen key:** `(message.id, requestId)` — composite.

| Option | Behavior | Decision |
|---|---|---|
| `message.id` alone | What the SDK doc documents as the minimum. | Sufficient in practice. |
| `(message.id, requestId)` | What ccusage uses; collapses only when **both** match. | **Chosen** — superset-safe. |

On real data the two are **identical**: no `message.id` maps to more than one `requestId`
(verified: 12,300 distinct under either key). We choose the composite because:

- It matches the established reference implementation (ccusage), easing cross-checking.
- It is strictly safer: if a future Claude Code format ever reused an ID across requests,
  the composite keeps them separate rather than silently merging.

**Both fields are top-level/nested-present** in real logs:
- `requestId` — top-level line field (e.g. `req_011Cax…`)
- `message.id` — nested in `message` (e.g. `msg_01Dso…`)

### Missing-key fallback

A line lacking **either** key cannot be safely grouped. Such a record is treated as
**its own unique group** (keyed by a per-record sentinel) and counted as-is. This is
conservative: it never merges records that might be distinct, at the cost of possibly
retaining a genuine duplicate that happens to lack keys (not observed in practice).

---

## 4. Collapse Rule: Last-Wins

Within a `(message.id, requestId)` group, keep **one** record:

> **Last occurrence in file order wins.**

Rationale, from the data and the SDK doc:

- Streaming snapshots accumulate `output_tokens` (`1 → 248`), so the **final** line holds
  the complete, billed value.
- Empirically, `last-wins == max-wins` on this machine (both 3,027,710,023). Last-wins is
  the simpler rule and matches the doc's "final message in a group."
- `first-wins` would **under-count** the 343 streaming groups → rejected.

Because input / cache_creation / cache_read are stable across a group's snapshots while
only `output_tokens` grows, taking the whole last record (not a field-wise max) is correct
and simplest.

### Ordering guarantee

Records are emitted in file-read order, and files are processed deterministically. Last-wins
relies only on per-file line order, which preserves streaming sequence (the final snapshot
is physically last in the file). Cross-file copies (resume/branch) are byte-identical for
the stable fields, so which file "wins" is immaterial.

---

## 5. Algorithm

```
parse:   for each assistant line with usage:
             emit TokenUsageRecord{ messageId, requestId, model,
                                    input, output, cacheCreation, cacheRead, timestamp }

analyze: allRecords = parse(all recent jsonl files)        // unchanged
         deduped    = collapseLastWins(allRecords)          // NEW
         partition deduped into today / yesterday by timestamp
         aggregate(today), aggregate(yesterday)             // unchanged math
```

### `collapseLastWins`

```swift
// Keep the last record seen per (messageId, requestId).
// Records missing either key are kept as-is (unique sentinel key).
func collapseLastWins(_ records: [TokenUsageRecord]) -> [TokenUsageRecord] {
    var lastByKey: [DedupKey: TokenUsageRecord] = [:]
    var order: [DedupKey] = []          // preserve first-seen order for stable output
    var sentinel = 0

    for record in records {
        let key: DedupKey
        if let id = record.messageId, let req = record.requestId {
            key = .composite(id, req)
        } else {
            key = .unkeyed(sentinel); sentinel += 1
        }
        if lastByKey[key] == nil { order.append(key) }
        lastByKey[key] = record       // last-wins overwrite
    }
    return order.map { lastByKey[$0]! }
}

enum DedupKey: Hashable {
    case composite(String, String)
    case unkeyed(Int)
}
```

**Where it runs:** in `ClaudeDailyUsageAnalyzer.analyzeToday()`, on the combined
`allRecords` array **before** today/yesterday partitioning — so duplicates split across
files (resume/branch) collapse globally, not just within one file.

**Complexity:** O(n) time, O(n) space over assistant lines in the 2-day window. Negligible
vs. existing file I/O.

---

## 6. Data Model Change

`TokenUsageRecord` gains two optional identity fields:

```swift
struct TokenUsageRecord: Sendable, Equatable {
    let messageId: String?      // NEW — message.id  (e.g. "msg_01Dso…")
    let requestId: String?      // NEW — top-level requestId (e.g. "req_011Cax…")
    let model: String
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
    let timestamp: Date
    var totalTokens: Int { inputTokens + outputTokens }
}
```

`SessionJSONLParser` reads `json["requestId"]` and `message["id"]` (both `as? String`),
defaulting to `nil` when absent. Both `parse(fileURL:)` and `parse(content:)` paths are
updated identically.

> The aggregation math in `aggregate(records:date:)` is **unchanged**. It simply receives a
> deduplicated array. Working-time / session-count estimation also benefits, since it no
> longer sees repeated timestamps.

---

## 7. Worked Example

Input lines for one response (streaming), plus one resume-copy in another file:

```
file A: msg_01X / req_9  in=7 out=1   cc=2499 cr=46316   t=10:00:00.1
file A: msg_01X / req_9  in=7 out=1   cc=2499 cr=46316   t=10:00:00.2
file A: msg_01X / req_9  in=7 out=248 cc=2499 cr=46316   t=10:00:00.9   ← final
file B: msg_01X / req_9  in=7 out=248 cc=2499 cr=46316   t=10:00:00.9   ← resume copy
```

- **Today (naive):** counts all 4 → output 1+1+248+248 = 498, totals ~4× inflated.
- **Today (last-wins):** one record kept → `in=7 out=248 cc=2499 cr=46316`. Correct,
  matches `/cost`.

---

## 8. Test Plan (Chicago-School, state-based)

Fixtures live as inline JSONL strings fed to `SessionJSONLParser.parse(content:)` and a
`ClaudeDailyUsageAnalyzer` with injected `now` and a temp `claudeDir`.

| # | Scenario | Assert |
|---|---|---|
| 1 | Parser captures `messageId` + `requestId` from a real-shaped line | fields populated |
| 2 | 3 byte-identical lines, same `(id,req)` | aggregate counts once |
| 3 | Streaming: output grows `1 → 248`, same `(id,req)` | keeps `output=248` (last/max) |
| 4 | Same `(id,req)` duplicated across **two files** (resume) | counts once globally |
| 5 | Two **distinct** responses (different ids) | both counted, no merge |
| 6 | Line missing `requestId` (or `id`) | kept as-is, not merged with others |
| 7 | Regression: known fixture → expected deduped cost/token totals | exact match |
| 8 | Working-time/session-count unaffected by dedup of same-timestamp dups | stable value |

Run: `xcodebuild test -scheme ClaudeBar-Workspace -workspace ClaudeBar.xcworkspace
-destination 'platform=macOS,arch=arm64'` (bypass Tuist test caching).

---

## 9. Rollout & Risk

- **Backward compatible:** new fields are optional; older lines without IDs still parse
  (counted as-is via the fallback).
- **User-visible effect:** Cost/Token cards drop to ~1/1.8–4× of prior values. This is the
  *correct* number, but it is a visible decrease — note it in the CHANGELOG so users don't
  read it as data loss. Frame as "Daily Usage now deduplicates streamed/duplicate session
  entries to match `claude /cost`."
- **No migration:** stateless recompute on next scan.
- **Estimate caveat:** cost remains a local estimate (price table); keep any "≈"/estimate
  affordance in the card copy if present.

---

## 10. Alternatives Considered

| Alternative | Why not |
|---|---|
| Dedup by `message.id` only | Equivalent on current data; composite is safer and matches ccusage. Acceptable fallback if `requestId` is ever absent project-wide. |
| First-wins / first-seen | Under-counts streaming groups' `output_tokens`. |
| Field-wise max across group | Equivalent to last-wins here but more code; only needed if stable fields ever varied (they don't). |
| Dedup inside each file only | Misses resume/branch copies that span files. Must dedup on the combined set. |
| Switch to an authoritative usage source (à la tokemon's OAuth path) | Larger, orthogonal change; doesn't block fixing the inflation. Possible future work. |

---

## References

- Issue [#207](https://github.com/tddworks/ClaudeBar/issues/207)
- [Anthropic Agent SDK — Track cost and usage](https://code.claude.com/docs/en/agent-sdk/cost-tracking)
- ccusage dedup rationale — [ryoppippi/ccusage#389](https://github.com/ryoppippi/ccusage/issues/389)
- claude-code [#6805](https://github.com/anthropics/claude-code/issues/6805) (3–8× stream-json over-count)
