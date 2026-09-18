import Foundation

/// Token pricing per 1M tokens for Claude models.
/// Prices from Anthropic's published pricing.
enum ModelPricing {
    struct Price {
        let inputPer1M: Decimal
        let outputPer1M: Decimal
        let cacheWritePer1M: Decimal
        let cacheReadPer1M: Decimal
    }

    /// Known model pricing (per 1M tokens in USD)
    static let prices: [String: Price] = [
        // Claude Opus 5 / 4.8 — Opus 5 launched 2026-07-24 at 4.8's price
        // point ($5/$25, cache write 1.25x, read 0.1x).
        // Sonnet 5: the planned $3/$15 step-up (2026-09-01) was cancelled on
        // 2026-08-10; $2/$10 is the permanent standard rate.
        "claude-opus-5": Price(inputPer1M: 5, outputPer1M: 25, cacheWritePer1M: 6.25, cacheReadPer1M: 0.50),
        "claude-opus-5-thinking": Price(inputPer1M: 5, outputPer1M: 25, cacheWritePer1M: 6.25, cacheReadPer1M: 0.50),
        "claude-opus-4-8": Price(inputPer1M: 5, outputPer1M: 25, cacheWritePer1M: 6.25, cacheReadPer1M: 0.50),
        "claude-sonnet-5": Price(inputPer1M: 2, outputPer1M: 10, cacheWritePer1M: 2.50, cacheReadPer1M: 0.20),

        // Claude Opus 4
        "claude-opus-4-20250514": Price(inputPer1M: 15, outputPer1M: 75, cacheWritePer1M: 18.75, cacheReadPer1M: 1.50),

        // Claude Opus 4.6
        "claude-opus-4-6": Price(inputPer1M: 5, outputPer1M: 25, cacheWritePer1M: 6.25, cacheReadPer1M: 0.50),

        // Claude Sonnet 4
        "claude-sonnet-4-20250514": Price(inputPer1M: 3, outputPer1M: 15, cacheWritePer1M: 3.75, cacheReadPer1M: 0.30),
        "claude-sonnet-4-6": Price(inputPer1M: 3, outputPer1M: 15, cacheWritePer1M: 3.75, cacheReadPer1M: 0.30),

        // Claude 3.5 Sonnet
        "claude-3-5-sonnet-20241022": Price(inputPer1M: 3, outputPer1M: 15, cacheWritePer1M: 3.75, cacheReadPer1M: 0.30),

        // Claude 3.5 Haiku
        "claude-3-5-haiku-20241022": Price(inputPer1M: 0.80, outputPer1M: 4, cacheWritePer1M: 1.00, cacheReadPer1M: 0.08),

        // Claude Haiku 4.5
        "claude-haiku-4-5-20251001": Price(inputPer1M: 1, outputPer1M: 5, cacheWritePer1M: 1.25, cacheReadPer1M: 0.10),
    ]

    /// Default pricing (Sonnet-level) for unknown models
    static let defaultPrice = Price(inputPer1M: 3, outputPer1M: 15, cacheWritePer1M: 3.75, cacheReadPer1M: 0.30)

    /// Look up pricing for a model, falling back to default
    static func price(for model: String) -> Price {
        // Try exact match first
        if let price = prices[model] { return price }

        // Try prefix matching (e.g., "claude-sonnet-4-6-20260101" matches "claude-sonnet-4-6")
        for (key, price) in prices {
            if model.hasPrefix(key) || key.hasPrefix(model) { return price }
        }

        // Infer from model name patterns
        if model.contains("opus") { return prices["claude-opus-4-6"]! }
        if model.contains("haiku") { return prices["claude-haiku-4-5-20251001"]! }

        return defaultPrice
    }

    /// Calculate cost for a token usage record
    static func cost(for record: TokenUsageRecord) -> Decimal {
        let p = price(for: record.model)
        let inputCost = Decimal(record.inputTokens) / 1_000_000 * p.inputPer1M
        let outputCost = Decimal(record.outputTokens) / 1_000_000 * p.outputPer1M
        let cacheWriteCost = Decimal(record.cacheCreationTokens) / 1_000_000 * p.cacheWritePer1M
        let cacheReadCost = Decimal(record.cacheReadTokens) / 1_000_000 * p.cacheReadPer1M
        return inputCost + outputCost + cacheWriteCost + cacheReadCost
    }

    /// Estimated savings from cache hits — what cache_read tokens would have cost
    /// at the full input price minus what they actually cost.
    static func savings(for record: TokenUsageRecord) -> Decimal {
        let p = price(for: record.model)
        return Decimal(record.cacheReadTokens) / 1_000_000 * (p.inputPer1M - p.cacheReadPer1M)
    }
}
