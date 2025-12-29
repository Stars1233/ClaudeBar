---
name: add-provider
description: |
  Guide for adding new AI providers to ClaudeBar using TDD patterns. Use this skill when:
  (1) Adding a new AI assistant provider (like Antigravity, Cursor, etc.)
  (2) Creating a usage probe for a CLI tool or local API
  (3) Following TDD to implement provider integration
  (4) User asks "how do I add a new provider" or "create a provider for X"
---

# Add Provider to ClaudeBar

Add new AI providers following established TDD patterns and architecture.

## Architecture Overview

```
Domain Layer (Sources/Domain/Provider/)
├── AIProvider protocol      → Provider class (e.g., AntigravityProvider)
└── UsageProbe protocol      → Implemented by Infrastructure

Infrastructure Layer (Sources/Infrastructure/CLI/)
├── *UsageProbe.swift        → Implements UsageProbe protocol
└── Uses: CLIExecutor, NetworkClient (mockable)

Tests (Tests/InfrastructureTests/CLI/)
├── *UsageProbeParsingTests.swift   → Test parsing logic
└── *UsageProbeTests.swift          → Test probe behavior
```

## TDD Workflow

### Phase 1: Parsing Tests (Red → Green)

Create `Tests/InfrastructureTests/CLI/{Provider}UsageProbeParsingTests.swift`:

```swift
import Testing
import Foundation
@testable import Infrastructure
@testable import Domain

@Suite
struct {Provider}UsageProbeParsingTests {

    static let sampleResponse = """
    { /* sample API/CLI response */ }
    """

    @Test func `parses quota into UsageQuota`() throws {
        let data = Data(Self.sampleResponse.utf8)
        let snapshot = try {Provider}UsageProbe.parseResponse(data, providerId: "{provider-id}")
        #expect(snapshot.quotas.count > 0)
    }

    @Test func `maps percentage correctly`() throws { /* ... */ }
    @Test func `parses reset time`() throws { /* ... */ }
    @Test func `extracts account email`() throws { /* ... */ }
    @Test func `handles missing data gracefully`() throws { /* ... */ }
}
```

### Phase 2: Probe Behavior Tests (Red → Green)

Create `Tests/InfrastructureTests/CLI/{Provider}UsageProbeTests.swift`:

```swift
import Testing
import Foundation
import Mockable
@testable import Infrastructure
@testable import Domain

@Suite
struct {Provider}UsageProbeTests {

    @Test func `isAvailable returns false when not detected`() async {
        let mockExecutor = MockCLIExecutor()
        given(mockExecutor).execute(...).willReturn(CLIResult(output: "", exitCode: 1))
        let probe = {Provider}UsageProbe(cliExecutor: mockExecutor)
        #expect(await probe.isAvailable() == false)
    }

    @Test func `isAvailable returns true when detected`() async { /* ... */ }
    @Test func `probe throws appropriate error when unavailable`() async { /* ... */ }
    @Test func `probe returns UsageSnapshot on success`() async { /* ... */ }
}
```

### Phase 3: Implement Probe

Create `Sources/Infrastructure/CLI/{Provider}UsageProbe.swift`:

```swift
import Foundation
import Domain

public struct {Provider}UsageProbe: UsageProbe {
    private let cliExecutor: any CLIExecutor
    private let networkClient: any NetworkClient
    private let timeout: TimeInterval

    public init(
        cliExecutor: (any CLIExecutor)? = nil,
        networkClient: (any NetworkClient)? = nil,
        timeout: TimeInterval = 8.0
    ) {
        self.cliExecutor = cliExecutor ?? DefaultCLIExecutor()
        self.networkClient = networkClient ?? URLSession.shared
        self.timeout = timeout
    }

    public func isAvailable() async -> Bool {
        // Detect if provider is available (binary exists, process running, etc.)
    }

    public func probe() async throws -> UsageSnapshot {
        // 1. Detect/authenticate
        // 2. Fetch quota data
        // 3. Parse and return UsageSnapshot
    }

    // Static parsing for testability
    static func parseResponse(_ data: Data, providerId: String) throws -> UsageSnapshot {
        // Parse response into domain models
    }
}
```

### Phase 4: Create Provider

Create `Sources/Domain/Provider/{Provider}Provider.swift`:

```swift
import Foundation
import Observation

@Observable
public final class {Provider}Provider: AIProvider, @unchecked Sendable {
    public let id: String = "{provider-id}"
    public let name: String = "{Provider Name}"
    public let cliCommand: String = "{cli-command}"

    public var dashboardURL: URL? { URL(string: "https://...") }
    public var statusPageURL: URL? { nil }

    public private(set) var isSyncing: Bool = false
    public private(set) var snapshot: UsageSnapshot?
    public private(set) var lastError: Error?

    private let probe: any UsageProbe

    public init(probe: any UsageProbe) {
        self.probe = probe
    }

    public func isAvailable() async -> Bool {
        await probe.isAvailable()
    }

    @discardableResult
    public func refresh() async throws -> UsageSnapshot {
        isSyncing = true
        defer { isSyncing = false }
        do {
            let newSnapshot = try await probe.probe()
            snapshot = newSnapshot
            lastError = nil
            return newSnapshot
        } catch {
            lastError = error
            throw error
        }
    }
}
```

### Phase 5: Register Provider

Add to `Sources/App/ClaudeBarApp.swift`:

```swift
var providers: [any AIProvider] = [
    ClaudeProvider(probe: ClaudeUsageProbe()),
    // ... existing providers
    {Provider}Provider(probe: {Provider}UsageProbe()),  // Add here
]
```

Add static accessor to `Sources/Domain/Provider/AIProviderRegistry.swift`:

```swift
public static var {providerId}: (any AIProvider)? {
    shared.provider(for: "{provider-id}")
}
```

## Domain Model Mapping

Map provider responses to existing domain models:

| Source Data | Domain Model |
|-------------|--------------|
| Quota percentage | `UsageQuota.percentRemaining` (0-100) |
| Model/tier name | `QuotaType.modelSpecific("name")` |
| Reset time | `UsageQuota.resetsAt` (Date) |
| Account email | `UsageSnapshot.accountEmail` |

## Error Handling

Use existing `ProbeError` enum:

```swift
ProbeError.cliNotFound("{Provider}")      // Binary/process not found
ProbeError.authenticationRequired          // Auth token missing/expired
ProbeError.executionFailed("message")      // Runtime errors
ProbeError.parseFailed("message")          // Parse errors
```

## Reference Implementation

See [references/antigravity-example.md](references/antigravity-example.md) for a complete working example showing:
- Full parsing test suite
- Probe behavior tests with mocking
- Probe implementation with process detection
- Provider class pattern

## Checklist

- [ ] Parsing tests created and passing
- [ ] Probe behavior tests created and passing
- [ ] Probe implementation complete
- [ ] Provider class created
- [ ] Provider registered in ClaudeBarApp
- [ ] Static accessor added to AIProviderRegistry
- [ ] All 300+ existing tests still pass
