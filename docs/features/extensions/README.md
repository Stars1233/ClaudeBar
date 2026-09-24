# Extensions Feature

User-built provider extensions for ClaudeBar. Drop a folder with a `manifest.json` and probe scripts into `~/.claudebar/extensions/` to add custom AI provider monitoring with your own data sources and card layouts.

---

## Quick Start

```bash
# Create an extension
mkdir -p ~/.claudebar/extensions/my-provider

# Add manifest.json (defines sections + probe commands)
cat > ~/.claudebar/extensions/my-provider/manifest.json <<'EOF'
{
    "id": "my-provider",
    "name": "My Provider",
    "version": "1.0.0",
    "icon": "cpu.fill",
    "colors": { "primary": "#FF6B35" },
    "config": [
        {
            "id": "apiKey",
            "label": "API Key",
            "type": "secret",
            "required": true,
            "placeholder": "sk-..."
        }
    ],
    "sections": [
        {
            "id": "quotas",
            "type": "quotaGrid",
            "probe": { "command": "./probe.sh", "interval": 60 }
        }
    ]
}
EOF

# Add probe script (any language — just output JSON to stdout)
# Config values are injected as CLAUDEBAR_* environment variables
cat > ~/.claudebar/extensions/my-provider/probe.sh <<'PROBE'
#!/bin/sh
curl -s -H "Authorization: Bearer $CLAUDEBAR_API_KEY" \
     https://api.example.com/usage | jq '{
    "quotas": [{"type": "weekly", "percentRemaining": (.remaining / .limit * 100)}]
}'
PROBE
chmod +x ~/.claudebar/extensions/my-provider/probe.sh

# Restart ClaudeBar — extension appears as a provider
# Open Settings to configure the API key
```

---

## Manifest Format (`manifest.json`)

| Field | Required | Description |
|-------|----------|-------------|
| `id` | Yes | Unique identifier (e.g., `"openrouter"`) |
| `name` | Yes | Display name shown in provider pills |
| `version` | Yes | Semver version string |
| `description` | No | Human-readable description |
| `icon` | No | SF Symbol name (e.g., `"cpu.fill"`, `"network"`) |
| `colors.primary` | No | Hex color for accent (e.g., `"#6366F1"`) |
| `colors.gradient` | No | Array of hex colors for gradient |
| `dashboardURL` | No | URL opened when user clicks "Dashboard" |
| `statusPageURL` | No | URL for provider status page |
| `config` | No | Array of config field definitions (see below) |
| `sections` | Yes | Array of section definitions (min 1) |

### Config Fields

Declare user-configurable settings that appear in ClaudeBar's Settings UI. Values are injected into probe scripts as environment variables.

| Field | Required | Description |
|-------|----------|-------------|
| `id` | Yes | Unique field identifier (becomes env var name) |
| `label` | Yes | Display label in settings UI |
| `type` | Yes | Field type (see below) |
| `required` | No | Whether the field must be set (default: `false`) |
| `default` | No | Default value when user hasn't configured |
| `placeholder` | No | Hint text shown in empty input |
| `helpText` | No | Description shown below the field |
| `options` | No | Array of choices (for `choice` type only) |

#### Config Field Types

| Type | UI Widget | Storage | Use Case |
|------|-----------|---------|----------|
| `string` | Text field | JSON settings | URLs, paths, names |
| `secret` | Secure field + show/hide | UserDefaults | API keys, tokens |
| `number` | Text field (numeric) | JSON settings | Budgets, limits, ports |
| `toggle` | Toggle switch | JSON settings | Feature flags |
| `choice` | Segmented picker | JSON settings | Mode selection, regions |
| `path` | Text field | JSON settings | File/directory paths |

#### Environment Variable Injection

Config values are injected into probe scripts as `CLAUDEBAR_*` environment variables. The field `id` is converted to `UPPER_SNAKE_CASE`:

| Field ID | Environment Variable |
|----------|---------------------|
| `apiKey` | `CLAUDEBAR_API_KEY` |
| `baseUrl` | `CLAUDEBAR_BASE_URL` |
| `monthly_budget` | `CLAUDEBAR_MONTHLY_BUDGET` |
| `base-url` | `CLAUDEBAR_BASE_URL` |

#### Config Storage

- **Non-secret fields** → `~/.claudebar/settings.json` under `extensions.<id>.<fieldId>`
- **Secret fields** (`type: "secret"`) → UserDefaults (Keychain migration planned)

```json
// ~/.claudebar/settings.json
{
    "extensions": {
        "openrouter": {
            "baseUrl": "https://openrouter.ai/api/v1",
            "monthlyBudget": "100.00",
            "modelFilter": "all"
        }
    }
}
```

### Section Definition

Each section has its own probe command and refresh interval for optimal performance:

| Field | Required | Description |
|-------|----------|-------------|
| `id` | Yes | Unique section identifier within the extension |
| `type` | Yes | Section type (see below) |
| `probe.command` | Yes | Script/binary to execute (relative to extension dir) |
| `probe.interval` | No | Refresh interval in seconds (default: `60`) |
| `probe.timeout` | No | Execution timeout in seconds (default: `10`) |

### Section Types

| Type | Renders As | Use Case |
|------|-----------|----------|
| `quotaGrid` | Quota cards with % bars and reset timers | Usage limits (session, weekly, model-specific) |
| `costUsage` | Cost card with budget tracking | Spending / billing data |
| `dailyUsage` | Comparison cards (cost, tokens, working time vs previous) | Daily analytics |
| `metricsRow` | Generic value cards with progress bars and deltas | Custom metrics (API calls, latency, etc.) |
| `statusBanner` | Simple status text with severity level | Connection status, health checks |

---

## Probe Script Output

Probe scripts are executed via `/bin/sh -c <command>` in the extension directory. They must:
1. Exit with code `0` on success (non-zero = error)
2. Print valid JSON to stdout
3. Complete within the configured timeout

Config values are available as `CLAUDEBAR_*` environment variables (see [Config Fields](#config-fields)).

Each section type expects a specific JSON key in the output:

### `quotaGrid` Output

```json
{
    "quotas": [
        {
            "type": "session",
            "percentRemaining": 97.0,
            "resetsAt": "2026-03-17T18:00:00Z"
        },
        {
            "type": "weekly",
            "percentRemaining": 69.0
        },
        {
            "type": "model:sonnet",
            "percentRemaining": 99.0,
            "dollarRemaining": 50.00
        }
    ]
}
```

**Quota type values:** `session`, `weekly`, `model:<name>`, or any custom string (rendered as `timeLimit`).

### `metricsRow` Output

```json
{
    "metrics": [
        {
            "label": "API Calls",
            "value": "1,234",
            "unit": "Requests",
            "icon": "arrow.up.arrow.down",
            "color": "#4CAF50",
            "progress": 0.65,
            "delta": {
                "vs": "Yesterday",
                "value": "+200",
                "percent": 19.3
            }
        }
    ]
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `label` | Yes | Card header text |
| `value` | Yes | Primary display value |
| `unit` | Yes | Unit label (e.g., "Requests", "USD", "ms") |
| `icon` | No | SF Symbol name |
| `color` | No | Hex color for accent |
| `progress` | No | Progress bar value (0.0–1.0) |
| `delta.vs` | No | Comparison reference (e.g., "Yesterday") |
| `delta.value` | No | Delta string (e.g., "+200", "-$5.00") |
| `delta.percent` | No | Change percentage |

### `costUsage` Output

```json
{
    "costUsage": {
        "totalCost": 10.26,
        "budget": 100.00,
        "apiDuration": 454.0,
        "wallDuration": 23600.0,
        "linesAdded": 150,
        "linesRemoved": 42
    }
}
```

### `dailyUsage` Output

```json
{
    "dailyUsage": {
        "today": {
            "totalCost": 10.26,
            "totalTokens": 8300000,
            "workingTime": 454.0,
            "date": "2026-03-17"
        },
        "previous": {
            "totalCost": 711.84,
            "totalTokens": 8693000,
            "workingTime": 42514.0,
            "date": "2026-03-16"
        }
    }
}
```

### `statusBanner` Output

```json
{
    "status": {
        "text": "Connected",
        "level": "healthy"
    }
}
```

**Level values:** `healthy`, `warning`, `critical`, `inactive`

---

## Multi-Section Example with Config

An OpenRouter extension with API key config, status checks, and usage tracking:

```json
{
    "id": "openrouter",
    "name": "OpenRouter",
    "version": "1.0.0",
    "icon": "network",
    "colors": {
        "primary": "#6366F1",
        "gradient": ["#6366F1", "#8B5CF6"]
    },
    "dashboardURL": "https://openrouter.ai/activity",
    "config": [
        {
            "id": "apiKey",
            "label": "API Key",
            "type": "secret",
            "required": true,
            "placeholder": "sk-or-v1-...",
            "helpText": "Find at openrouter.ai/keys"
        },
        {
            "id": "monthlyBudget",
            "label": "Monthly Budget",
            "type": "number",
            "default": "100",
            "placeholder": "100.00",
            "helpText": "USD spending limit for cost tracking"
        }
    ],
    "sections": [
        {
            "id": "status",
            "type": "statusBanner",
            "probe": { "command": "./probe-status.sh", "interval": 30, "timeout": 5 }
        },
        {
            "id": "quotas",
            "type": "quotaGrid",
            "probe": { "command": "./probe-quota.sh", "interval": 60 }
        },
        {
            "id": "daily",
            "type": "metricsRow",
            "probe": { "command": "./probe-metrics.sh", "interval": 300, "timeout": 15 }
        }
    ]
}
```

Each probe runs independently on its own interval, so fast health checks don't wait for heavy analytics. Probe scripts access `$CLAUDEBAR_API_KEY` and `$CLAUDEBAR_MONTHLY_BUDGET` automatically.

---

## Architecture

```
ClaudeBarApp.init()
└── ExtensionRegistry.loadExtensions(into: monitor)
    └── ExtensionDirectoryScanner.scan(~/.claudebar/extensions/)
        └── For each valid manifest.json:
            ├── Parse → ExtensionManifest (with configFields)
            ├── Create ScriptProbe per section (with config injection)
            ├── Create ExtensionProvider (implements AIProvider)
            └── QuotaMonitor.addProvider(extensionProvider)
                 ↓
            Provider appears in UI alongside built-in providers
            Config card appears in Settings (if config fields declared)
```

```
Sources/
├── Domain/Extension/
│   ├── ExtensionManifest.swift       [manifest.json → typed struct with sections + config]
│   ├── ExtensionSection.swift        [section type, probe command, interval, timeout]
│   ├── ExtensionMetric.swift         [generic metric + MetricDelta + StatusInfo]
│   ├── ExtensionProvider.swift       [AIProvider — owns N probes, merges snapshots]
│   ├── ConfigField.swift             [config field type, env var name, effective value]
│   ├── ExtensionConfigStore.swift    [ExtensionConfigRepository protocol]
│   └── SectionData.swift             [decodes probe JSON → UsageQuota/CostUsage/etc.]
├── Infrastructure/Extension/
│   ├── ScriptProbe.swift             [UsageProbe — executes script with config env vars]
│   ├── JSONExtensionConfigStore.swift [persists config: JSON + UserDefaults for secrets]
│   ├── ExtensionDirectoryScanner.swift [scans extensions dir for manifest.json]
│   └── ExtensionRegistry.swift       [wires scanning → provider creation → registration]
└── App/
    ├── Settings/AppSettings.swift    [exposes extensionConfig repository]
    └── Views/
        ├── Settings/ExtensionConfigCard.swift [dynamic config UI from manifest]
        └── ExtensionMetricCardView.swift      [renders generic metric cards]
```

---

## Domain Models

### `ExtensionManifest`

Parsed from `manifest.json`. Contains extension identity, visual config, config fields, and section definitions.

```swift
public struct ExtensionManifest: Sendable, Equatable {
    public let id: String
    public let name: String
    public let version: String
    public let description: String?
    public let icon: String?
    public let colors: ExtensionColors?
    public let dashboardURL: URL?
    public let statusPageURL: URL?
    public let configFields: [ConfigField]
    public let sections: [ExtensionSection]

    public var hasConfig: Bool { !configFields.isEmpty }
}
```

### `ConfigField`

A user-configurable field declared in the manifest. Drives both the Settings UI and env var injection.

```swift
public struct ConfigField: Sendable, Equatable, Codable {
    public let id: String               // e.g., "apiKey"
    public let label: String            // e.g., "API Key"
    public let type: ConfigFieldType    // .string, .secret, .number, .toggle, .choice, .path
    public let required: Bool
    public let defaultValue: String?    // JSON key: "default"
    public let placeholder: String?
    public let helpText: String?
    public let options: [String]?       // for .choice type

    public var isSecret: Bool           // true when type == .secret
    public var environmentVariableName: String  // "apiKey" → "CLAUDEBAR_API_KEY"
    public func effectiveValue(stored: String?) -> String?  // stored ?? default
}
```

### `ExtensionSection`

A single section within an extension, with its own probe and refresh interval.

```swift
public struct ExtensionSection: Sendable, Equatable {
    public let id: String
    public let type: SectionType          // .quotaGrid, .metricsRow, .costUsage, .dailyUsage, .statusBanner
    public let probeCommand: String       // relative to extension dir
    public let refreshInterval: TimeInterval  // default: 60s
    public let timeout: TimeInterval          // default: 10s
}
```

### `ExtensionMetric`

Generic metric value for `metricsRow` sections.

```swift
public struct ExtensionMetric: Sendable, Equatable, Codable {
    public let label: String
    public let value: String
    public let unit: String
    public let icon: String?              // SF Symbol name
    public let color: String?             // hex color
    public let delta: MetricDelta?        // comparison data
    public let progress: Double?          // 0.0–1.0
}
```

### `SectionData`

Enum that decodes probe JSON into the correct domain model based on section type.

```swift
public enum SectionData: Sendable, Equatable {
    case quotas([UsageQuota])        // reuses existing model
    case cost(CostUsage)             // reuses existing model
    case daily(DailyUsageReport)     // reuses existing model
    case metrics([ExtensionMetric])  // new
    case status(StatusInfo)          // new
}
```

---

## File Map

**Sources:**

```
Sources/
├── Domain/Extension/
│   ├── ExtensionManifest.swift
│   ├── ExtensionSection.swift
│   ├── ExtensionMetric.swift
│   ├── ExtensionProvider.swift
│   ├── ConfigField.swift
│   ├── ExtensionConfigStore.swift
│   └── SectionData.swift
├── Infrastructure/Extension/
│   ├── ScriptProbe.swift
│   ├── JSONExtensionConfigStore.swift
│   ├── ExtensionDirectoryScanner.swift
│   └── ExtensionRegistry.swift
└── App/
    ├── Settings/AppSettings.swift
    └── Views/
        ├── Settings/ExtensionConfigCard.swift
        └── ExtensionMetricCardView.swift
```

**Tests:**

```
Tests/
├── DomainTests/Extension/
│   ├── ConfigFieldTests.swift                [12 tests — decoding, env vars, secrets, defaults]
│   ├── ExtensionManifestTests.swift          [14 tests — parsing, defaults, validation, config]
│   ├── ExtensionMetricTests.swift            [6 tests — model creation, JSON decoding]
│   ├── SectionDataTests.swift                [10 tests — all 5 section types, errors]
│   └── ExtensionProviderTests.swift          [10 tests — identity, refresh, merge, availability]
└── InfrastructureTests/Extension/
    ├── ScriptProbeTests.swift                [9 tests — execution, parsing, errors, config injection]
    ├── JSONExtensionConfigRepositoryTests.swift [9 tests — store, secrets, isolation, allValues]
    └── ExtensionDirectoryScannerTests.swift  [5 tests — scanning, validation, missing dirs]
```

---

## Testing

```swift
@Test func `parses manifest with config fields`() throws {
    let json = """
    {
        "id": "test", "name": "Test", "version": "1.0.0",
        "config": [
            { "id": "apiKey", "label": "API Key", "type": "secret", "required": true },
            { "id": "baseUrl", "label": "URL", "type": "string", "default": "https://api.example.com" }
        ],
        "sections": [
            { "id": "q", "type": "quotaGrid", "probe": { "command": "./probe.sh" } }
        ]
    }
    """
    let manifest = try ExtensionManifest.parse(from: json.data(using: .utf8)!)
    #expect(manifest.configFields.count == 2)
    #expect(manifest.configFields[0].type == .secret)
    #expect(manifest.configFields[0].environmentVariableName == "CLAUDEBAR_API_KEY")
}
```

Run extension tests:

```bash
xcodebuild test -scheme ClaudeBar-Workspace -workspace ClaudeBar.xcworkspace \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:DomainTests/ConfigFieldTests \
  -only-testing:DomainTests/ExtensionManifestTests \
  -only-testing:DomainTests/ExtensionMetricTests \
  -only-testing:DomainTests/SectionDataTests \
  -only-testing:DomainTests/ExtensionProviderTests \
  -only-testing:InfrastructureTests/ScriptProbeTests \
  -only-testing:InfrastructureTests/JSONExtensionConfigRepositoryTests \
  -only-testing:InfrastructureTests/ExtensionDirectoryScannerTests
# Test run with 75 tests in 8 suites passed
```

---

## Security

- Probe scripts run with the user's permissions (not elevated)
- Timeout enforcement prevents hanging scripts (default 10s)
- JSON-only output — no code injection into the app
- Extensions cannot access app internals; they only produce data via stdout
- Extension provider IDs are prefixed with `ext-` to avoid collisions with built-in providers
- Secret config values are stored in UserDefaults (Keychain migration planned), not in settings JSON
- Config values are injected via `env` command, not embedded in script arguments
