# ClaudeBar

[![Build](https://github.com/tddworks/ClaudeBar/actions/workflows/build.yml/badge.svg)](https://github.com/tddworks/ClaudeBar/actions/workflows/build.yml)
[![Tests](https://github.com/tddworks/ClaudeBar/actions/workflows/tests.yml/badge.svg)](https://github.com/tddworks/ClaudeBar/actions/workflows/tests.yml)
[![codecov](https://codecov.io/gh/tddworks/ClaudeBar/graph/badge.svg)](https://codecov.io/gh/tddworks/ClaudeBar)
[![Latest Release](https://img.shields.io/github/v/release/tddworks/ClaudeBar)](https://github.com/tddworks/ClaudeBar/releases/latest)
[![Swift 6.2](https://img.shields.io/badge/Swift-6.2-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%2015-blue.svg)](https://developer.apple.com)
[![Homebrew](https://img.shields.io/badge/Homebrew-Install-brightgreen.svg)](https://formulae.brew.sh/cask/claudebar)

A macOS menu bar application that monitors AI coding assistant usage quotas. Keep track of your Claude, Codex, Gemini, GitHub Copilot, Antigravity, Z.ai, Kimi, Kiro, Amp, OpenCode Go, Oh My Pi, Grok, and more at a glance.

<table align="center">
  <tr>
    <td align="center"><img src="docs/screenshots/Screenshot-dark.png" alt="Dark Mode" width="360"/><br/><em>Dark Mode</em></td>
    <td align="center"><img src="docs/screenshots/Screenshot-light.png" alt="Light Mode" width="360"/><br/><em>Light Mode</em></td>
  </tr>
  <tr>
    <td align="center"><img src="docs/screenshots/Screenshot-cli-dark.png" alt="CLI Theme" width="360"/><br/><em>CLI Theme</em></td>
    <td align="center"><img src="docs/screenshots/Christmas-theme.png" alt="Christmas Theme" width="360"/><br/><em>Christmas Theme</em></td>
  </tr>
</table>

## Sponsors

Some companies support ClaudeBar's open source development through [GitHub Sponsors](https://github.com/sponsors/hanrw). We'd like to give a special mention to the following sponsors:

<table>
  <tbody>
    <tr>
      <td width="30%" align="center">
        <a href="https://www.testmuai.com/?utm_source=ClaudeBar&utm_medium=opensourcecollab" target="_blank">
          <picture>
            <source media="(prefers-color-scheme: dark)" srcset="docs/sponsors/testmuai/testmuai-dark.svg"/>
            <img width="220" src="docs/sponsors/testmuai/testmuai-light.svg" alt="testmuai_logo"/>
          </picture>
        </a>
      </td>
      <td><a href="https://www.testmuai.com/?utm_source=ClaudeBar&utm_medium=opensourcecollab">TestMu AI</a> (formerly LambdaTest) is the world's first full-stack agentic AI quality engineering platform, trusted by 18,000+ enterprises.</td>
    </tr>
  </tbody>
</table>

> **Editorial independence:** Sponsorship does not influence which providers ClaudeBar supports, how they are ordered in the app, or how their quota data is reported.

## Features

- **Multi-Provider Support** - Monitor Claude, Codex, Gemini, GitHub Copilot, Antigravity, Z.ai, Kimi, Kiro, Amp, OpenCode Go, Oh My Pi, and Grok quotas in one place
- **Provider Enable/Disable** - Toggle individual providers on/off from Settings to customize your monitoring
- **Real-Time Quota Tracking** - View Session, Weekly, and Model-specific usage percentages
- **Multiple Themes** - Light, Dark, CLI, Christmas, and [imported terminal themes](#import-terminal-theme) (.itermcolors)
- **Automatic Adaptation** - System theme follows your macOS appearance; Christmas auto-enables during the holiday season
- **Visual Status Indicators** - Color-coded progress bars (green/yellow/red) show quota health
- **System Notifications** - Get alerted when quota status changes to warning or critical
- **Touch Bar Integration** - Persistent MacBook Touch Bar widget with real-time multi-provider gauges, progress bars, and an interactive pixel mascot ([learn more](#claudebar-with-touch-bar))
- **Auto-Refresh** - Automatically updates quotas at configurable intervals
- **Keyboard Shortcuts** - Quick access with `⌘D` (Dashboard) and `⌘R` (Refresh)

## Quota Status Thresholds

| Remaining | Status | Color |
|-----------|--------|-------|
| > 50% | Healthy | Green |
| 20-50% | Warning | Yellow |
| < 20% | Critical | Red |
| 0% | Depleted | Gray |

## ClaudeBar with Touch Bar

ClaudeBar features native, system-wide Touch Bar integration for MacBook Pro models equipped with a Touch Bar (including M1/M2 and Intel). Inspired by the beloved [`tpklo/claude-usage-touchbar`](https://github.com/tpklo/claude-usage-touchbar), this runs 100% natively inside ClaudeBar—requiring **no third-party apps** (no BetterTouchTool or MTMR required).

<p align="center">
  <img src="docs/screenshots/TouchBar-preview.png" alt="ClaudeBar with Touch Bar" width="100%"/>
</p>

### Key Touch Bar Features

- **Always Visible Across All Windows & Apps**: Uses macOS system-modal function bar presentation (`placement: 0`). The widget remains persistently visible on your Touch Bar regardless of which application is active, automatically re-asserting on app switching and system unlock while keeping your system Escape key and Control Strip media/volume controls intact.
- **Interactive Pixel Mascot (Clawd)**:
  - An animated 20×20 retro creature pacing along a subtle ground line.
  - **Mood-Reactive Gauge**: The creature's speed and animation adapt to your highest quota usage:
    - **Calm** (< 30%): A relaxed, peaceful stroll.
    - **Brisk** (30%–59%): Picking up the pace as coding intensifies.
    - **Tired** (60%–84%): Moving sluggishly with animated sweat drops.
    - **Panic** (≥ 85%): Frantic scurrying with speed streaks trailing behind!
  - **Direct Touch Interaction**: Touch and drag Clawd across the Touch Bar, or flick him with realistic velocity and friction decay.
- **Live Multi-Provider Quota Gauges**:
  - Displays real provider logo icons (Claude, Gemini, Antigravity, GitHub Copilot, Codex, etc.) with rounded styling.
  - Renders multi-segment provider views matching your menu bar configuration (e.g. `[Logo] Gemini 40% | [Logo] Claude 0%`).
  - High-precision bold monospaced percentage readout with warning indicator (`!`) when quota is critical (≥ 90%).
  - Sleek progress bars with 100% track reference, adaptive color coding (Blue < 50%, Amber 50%–89%, Alert Red ≥ 90%), and scale tick marks at **50%** and **90%**.
  - Reset countdown timer (e.g., `2h15` or remaining duration).
- **One-Tap Access**: Tap anywhere on the quota gauges on the Touch Bar to instantly summon the full ClaudeBar dropdown popover.

### Enabling or Disabling Touch Bar

You can toggle the persistent Touch Bar on or off at any time from **Settings > General > Touch Bar**:

<p align="center">
  <img src="docs/screenshots/TouchBar-settings.png" alt="Touch Bar Settings" width="680"/>
</p>

## Requirements

- macOS 15+
- Swift 6.2+
- CLI tools installed for providers you want to monitor:
  - [Claude CLI](https://claude.ai/code) (`claude`)
  - [Codex CLI](https://github.com/openai/codex) (`codex`)
  - [Gemini CLI](https://github.com/google-gemini/gemini-cli) (`gemini`)
  - [GitHub Copilot](https://github.com/features/copilot) - Configure credentials in Settings
  - [Antigravity](https://antigravity.google) - Auto-detected when running locally
  - [Z.ai](https://z.ai/subscribe) - Configure Claude Code with GLM Coding Plan endpoint
  - [Kimi](https://www.kimi.com/code/console) (`kimi`) - CLI mode (recommended) or API mode (see below)
  - [Kiro](https://kiro.dev) (`kiro-cli`) - Requires kiro-cli installation (see below)
  - [Amp](https://ampcode.com) (`amp`) - Auto-detected when CLI is installed
  - [OpenCode Go](https://opencode.ai/go) (`opencode`) - Tracks OpenCode Go usage windows (5hr/$12, weekly/$30, monthly/$60) via local SQLite DB
  - [Oh My Pi](https://omp.sh) (`omp`) - Aggregates account usage via `omp usage --json`, showing rate-limit windows and, where reported, capped USD money cards or uncapped spend notes
  - [Grok Build](https://docs.x.ai) (`grok`) - Tracks xAI credit usage (weekly window + per-product Grok Build / Imagine / Voice limits) using the CLI's local OAuth credentials

### Kimi Setup

Kimi supports two probe modes, configurable in **Settings > Kimi Configuration**:

**CLI Mode (Recommended)** - Launches the interactive `kimi` CLI and sends `/usage` to fetch quota data. Requires `kimi` CLI installed (`uv tool install kimi-cli`). No Full Disk Access needed.

**API Mode** - Calls the Kimi API directly using browser cookie authentication. Requires **Full Disk Access** for ClaudeBar to read the `kimi-auth` browser cookie:
1. Open **System Settings** > **Privacy & Security** > **Full Disk Access**
2. Toggle **ClaudeBar** on (or click `+` and add it)
3. Restart ClaudeBar

You can also set the `KIMI_AUTH_TOKEN` environment variable to bypass cookie reading in API mode.

### Kiro Setup

Kiro monitors AWS Kiro (formerly CodeWhisperer) usage through the `kiro-cli` command-line tool.

**Installation**: `uv tool install kiro-cli` or `pip install kiro-cli`

**Authentication**: Run `kiro-cli` and follow the login prompts.

**Kiro IDE Users**: If you use Kiro IDE, simply install kiro-cli. Both share the same authentication, so no additional login is required.

## Installation

### Homebrew

Install via [Homebrew](https://brew.sh).

```bash
brew install --cask claudebar
```

### Download (Recommended)

Download the latest release from [GitHub Releases](https://github.com/tddworks/ClaudeBar/releases/latest):

- **DMG**: Open and drag ClaudeBar.app to Applications
- **ZIP**: Unzip and move ClaudeBar.app to Applications

Both are code-signed and notarized for Gatekeeper.

### Build from Source

```bash
git clone https://github.com/tddworks/ClaudeBar.git
cd ClaudeBar

# Install Tuist (if not installed)
brew install tuist

# Install dependencies and build
tuist install
tuist build ClaudeBar -C Release
```

## Usage

After building, open the generated Xcode workspace and run the app:

```bash
tuist generate
open ClaudeBar.xcworkspace
```

Then press `Cmd+R` in Xcode to run. The app will appear in your menu bar. Click to view quota details for each provider.

## Development

The project uses [Tuist](https://tuist.io) for dependency management and Xcode project generation.

### Quick Start

```bash
# Install Tuist (if not installed)
brew install tuist

# Install dependencies
tuist install

# Generate Xcode project and open
tuist generate
open ClaudeBar.xcworkspace
```

### Build & Test

```bash
# Build the project
tuist build

# Run all tests
tuist test

# Run tests with coverage
tuist test --result-bundle-path TestResults.xcresult -- -enableCodeCoverage YES

# Build release configuration
tuist build ClaudeBar -C Release
```

### SwiftUI Previews

After opening in Xcode, SwiftUI previews will work with `Cmd+Option+Return`. The project is configured with `ENABLE_DEBUG_DYLIB` for preview support.

## Architecture

> **Full documentation:** [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)

ClaudeBar uses a **layered architecture** with `QuotaMonitor` as the single source of truth:

| Layer | Purpose |
|-------|---------|
| **App** | SwiftUI views consuming domain directly (no ViewModel) |
| **Domain** | Rich models, `QuotaMonitor`, repository protocols |
| **Infrastructure** | Probes, storage implementations, adapters |

### Key Design Decisions

- **Single Source of Truth** - `QuotaMonitor` owns all provider state
- **Repository Pattern** - Settings and credentials abstracted behind injectable protocols
- **Protocol-Based DI** - `@Mockable` protocols enable testability
- **Chicago School TDD** - Tests verify state changes, not method calls
- **No ViewModel/AppState** - Views consume domain directly

## Import Terminal Theme

Match ClaudeBar's appearance to your terminal. Import any `.itermcolors` file:

1. Open **Settings** (gear icon)
2. Click **Import .itermcolors**
3. Select your file (export from iTerm2: Preferences > Profiles > Colors > Color Presets > Export)

450+ pre-made schemes available at [iTerm2-Color-Schemes](https://github.com/mbadolato/iTerm2-Color-Schemes/tree/master/schemes).

Imported themes are saved in `~/.claudebar/themes/` and persist across restarts.

## Contributing

### Adding a New AI Provider

Use the **add-provider** skill to guide you through adding new providers with TDD:

```
Tell Claude Code: "I want to add a new provider for [ProviderName]"
```

The skill guides you through: Parsing Tests → Probe Tests → Implementation → Registration.

See `.claude/skills/add-provider/SKILL.md` for details and `AntigravityUsageProbe` as a reference implementation.

## Dependencies

- [Sparkle](https://sparkle-project.org/) - Auto-update framework
- [Mockable](https://github.com/Kolos65/Mockable) - Protocol mocking for tests
- [Tuist](https://tuist.io) - Xcode project generation (for SwiftUI previews)

## Releasing

Releases are automated via GitHub Actions. Push a version tag to create a new release.

**For detailed setup instructions, see [docs/release/RELEASE_SETUP.md](docs/release/RELEASE_SETUP.md).**

### Release Workflow

The workflow uses Tuist to generate the Xcode project:

```
Tag v1.0.0 → Update Info.plist → tuist generate → xcodebuild → Sign & Notarize → GitHub Release
```

Version is set in `Sources/App/Info.plist` and flows through to Sparkle auto-updates.

### Quick Start

1. **Configure GitHub Secrets** (see [full guide](docs/release/RELEASE_SETUP.md)):

   | Secret | Description |
   |--------|-------------|
   | `APPLE_CERTIFICATE_P12` | Developer ID certificate (base64) |
   | `APPLE_CERTIFICATE_PASSWORD` | Password for .p12 |
   | `APP_STORE_CONNECT_API_KEY_P8` | API key (base64) |
   | `APP_STORE_CONNECT_KEY_ID` | Key ID |
   | `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID |

2. **Verify your certificate**:
   ```bash
   ./scripts/verify-p12.sh /path/to/certificate.p12
   ```

3. **Create a release**:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

The workflow will automatically build, sign, notarize, and publish to GitHub Releases.

## Contributors

Thanks goes to these wonderful people ([emoji key](https://allcontributors.org/docs/en/emoji-key)):

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->
<table>
  <tbody>
    <tr>
      <td align="center" valign="top" width="16.66%"><a href="https://tddworks.com/"><img src="https://avatars.githubusercontent.com/u/1201118?v=4?s=80" width="80px;" alt="itshan"/><br /><sub><b>itshan</b></sub></a><br /><a href="https://github.com/tddworks/claudebar/commits?author=hanrw" title="Code">💻</a> <a href="https://github.com/tddworks/claudebar/commits?author=hanrw" title="Documentation">📖</a> <a href="#maintenance-hanrw" title="Maintenance">🚧</a></td>
      <td align="center" valign="top" width="16.66%"><a href="https://github.com/avishj"><img src="https://avatars.githubusercontent.com/u/58023328?v=4?s=80" width="80px;" alt="Avish Jha"/><br /><sub><b>Avish Jha</b></sub></a><br /><a href="https://github.com/tddworks/claudebar/commits?author=avishj" title="Code">💻</a></td>
      <td align="center" valign="top" width="16.66%"><a href="https://github.com/ramarivera"><img src="https://avatars.githubusercontent.com/u/7547875?v=4?s=80" width="80px;" alt="Ramiro"/><br /><sub><b>Ramiro</b></sub></a><br /><a href="https://github.com/tddworks/claudebar/commits?author=ramarivera" title="Code">💻</a></td>
      <td align="center" valign="top" width="16.66%"><a href="https://github.com/LunarECL"><img src="https://avatars.githubusercontent.com/u/38317983?v=4?s=80" width="80px;" alt="LunarECL"/><br /><sub><b>LunarECL</b></sub></a><br /><a href="https://github.com/tddworks/claudebar/commits?author=LunarECL" title="Code">💻</a></td>
      <td align="center" valign="top" width="16.66%"><a href="https://github.com/zenibako"><img src="https://avatars.githubusercontent.com/u/18584424?v=4?s=80" width="80px;" alt="Chandler Anderson"/><br /><sub><b>Chandler Anderson</b></sub></a><br /><a href="https://github.com/tddworks/claudebar/commits?author=zenibako" title="Code">💻</a></td>
      <td align="center" valign="top" width="16.66%"><a href="https://frmr.me"><img src="https://avatars.githubusercontent.com/u/620189?v=4?s=80" width="80px;" alt="Matt Farmer"/><br /><sub><b>Matt Farmer</b></sub></a><br /><a href="https://github.com/tddworks/claudebar/commits?author=farmdawgnation" title="Code">💻</a></td>
    </tr>
    <tr>
      <td align="center" valign="top" width="16.66%"><a href="https://willner.ws"><img src="https://avatars.githubusercontent.com/u/307605?v=4?s=80" width="80px;" alt="Alex"/><br /><sub><b>Alex</b></sub></a><br /><a href="https://github.com/tddworks/claudebar/commits?author=AlexanderWillner" title="Code">💻</a></td>
      <td align="center" valign="top" width="16.66%"><a href="https://github.com/sailesh"><img src="https://avatars.githubusercontent.com/u/493129?v=4?s=80" width="80px;" alt="sailesh"/><br /><sub><b>sailesh</b></sub></a><br /><a href="https://github.com/tddworks/claudebar/commits?author=sailesh" title="Code">💻</a></td>
      <td align="center" valign="top" width="16.66%"><a href="https://github.com/billyjack2"><img src="https://avatars.githubusercontent.com/u/28798344?v=4?s=80" width="80px;" alt="Billy Smith"/><br /><sub><b>Billy Smith</b></sub></a><br /><a href="https://github.com/tddworks/claudebar/commits?author=billyjack2" title="Code">💻</a></td>
      <td align="center" valign="top" width="16.66%"><a href="https://github.com/nero-sensei"><img src="https://avatars.githubusercontent.com/u/77715088?v=4?s=80" width="80px;" alt="nero"/><br /><sub><b>nero</b></sub></a><br /><a href="https://github.com/tddworks/claudebar/commits?author=nero-sensei" title="Code">💻</a></td>
      <td align="center" valign="top" width="16.66%"><a href="https://github.com/BryanQQYue"><img src="https://avatars.githubusercontent.com/u/169884865?v=4?s=80" width="80px;" alt="BryanYue"/><br /><sub><b>BryanYue</b></sub></a><br /><a href="https://github.com/tddworks/claudebar/commits?author=BryanQQYue" title="Code">💻</a></td>
      <td align="center" valign="top" width="16.66%"><a href="https://blog.d0zingcat.dev/"><img src="https://avatars.githubusercontent.com/u/8235790?v=4?s=80" width="80px;" alt="Tony Tang"/><br /><sub><b>Tony Tang</b></sub></a><br /><a href="https://github.com/tddworks/claudebar/commits?author=d0zingcat" title="Code">💻</a></td>
    </tr>
    <tr>
      <td align="center" valign="top" width="16.66%"><a href="https://initialize.nl/"><img src="https://avatars.githubusercontent.com/u/7355878?v=4?s=80" width="80px;" alt="Frank Hommers"/><br /><sub><b>Frank Hommers</b></sub></a><br /><a href="https://github.com/tddworks/claudebar/commits?author=frankhommers" title="Code">💻</a></td>
      <td align="center" valign="top" width="16.66%"><a href="https://www.marcusquinn.com"><img src="https://avatars.githubusercontent.com/u/6428977?v=4?s=80" width="80px;" alt="Marcus Quinn"/><br /><sub><b>Marcus Quinn</b></sub></a><br /><a href="https://github.com/tddworks/claudebar/commits?author=marcusquinn" title="Code">💻</a></td>
      <td align="center" valign="top" width="16.66%"><a href="https://github.com/hagiwaratakayuki"><img src="https://avatars.githubusercontent.com/u/141513?v=4?s=80" width="80px;" alt="hagiwara takayuki"/><br /><sub><b>hagiwara takayuki</b></sub></a><br /><a href="https://github.com/tddworks/claudebar/commits?author=hagiwaratakayuki" title="Code">💻</a></td>
      <td align="center" valign="top" width="16.66%"><a href="https://github.com/jeffscottmtl"><img src="https://avatars.githubusercontent.com/u/33327731?v=4?s=80" width="80px;" alt="jeffscottmtl"/><br /><sub><b>jeffscottmtl</b></sub></a><br /><a href="https://github.com/tddworks/claudebar/commits?author=jeffscottmtl" title="Code">💻</a></td>
      <td align="center" valign="top" width="16.66%"><a href="https://github.com/tomstetson"><img src="https://avatars.githubusercontent.com/u/11658911?v=4?s=80" width="80px;" alt="Tom"/><br /><sub><b>Tom</b></sub></a><br /><a href="https://github.com/tddworks/claudebar/commits?author=tomstetson" title="Code">💻</a></td>
      <td align="center" valign="top" width="16.66%"><a href="https://github.com/jeffWelling"><img src="https://avatars.githubusercontent.com/u/105077?v=4?s=80" width="80px;" alt="Jeff Welling"/><br /><sub><b>Jeff Welling</b></sub></a><br /><a href="https://github.com/tddworks/claudebar/commits?author=jeffWelling" title="Code">💻</a></td>
    </tr>
    <tr>
      <td align="center" valign="top" width="16.66%"><a href="https://github.com/Zada5"><img src="https://avatars.githubusercontent.com/u/91982194?v=4?s=80" width="80px;" alt="Zada5"/><br /><sub><b>Zada5</b></sub></a><br /><a href="https://github.com/tddworks/claudebar/commits?author=Zada5" title="Code">💻</a></td>
      <td align="center" valign="top" width="16.66%"><a href="https://github.com/fredericoricco-debug"><img src="https://avatars.githubusercontent.com/u/75469834?v=4?s=80" width="80px;" alt="fredericoricco-debug"/><br /><sub><b>fredericoricco-debug</b></sub></a><br /><a href="https://github.com/tddworks/claudebar/commits?author=fredericoricco-debug" title="Code">💻</a></td>
      <td align="center" valign="top" width="16.66%"><a href="https://lystic.dev"><img src="https://avatars.githubusercontent.com/u/15372623?v=4?s=80" width="80px;" alt="Kegan Hollern"/><br /><sub><b>Kegan Hollern</b></sub></a><br /><a href="https://github.com/tddworks/claudebar/commits?author=KeganHollern" title="Code">💻</a></td>
      <td align="center" valign="top" width="16.66%"><a href="https://github.com/jsg333"><img src="https://avatars.githubusercontent.com/u/954990?v=4?s=80" width="80px;" alt="Jeff Green"/><br /><sub><b>Jeff Green</b></sub></a><br /><a href="https://github.com/tddworks/claudebar/commits?author=jsg333" title="Code">💻</a></td>
      <td align="center" valign="top" width="16.66%"><a href="https://github.com/benjaminbelaga"><img src="https://avatars.githubusercontent.com/u/33546317?v=4?s=80" width="80px;" alt="Benjamin Belaga"/><br /><sub><b>Benjamin Belaga</b></sub></a><br /><a href="https://github.com/tddworks/claudebar/commits?author=benjaminbelaga" title="Code">💻</a></td>
      <td align="center" valign="top" width="16.66%"><a href="https://github.com/romanvalent"><img src="https://avatars.githubusercontent.com/u/14106124?v=4?s=80" width="80px;" alt="romanvalent"/><br /><sub><b>romanvalent</b></sub></a><br /><a href="https://github.com/tddworks/claudebar/commits?author=romanvalent" title="Code">💻</a></td>
    </tr>
    <tr>
      <td align="center" valign="top" width="16.66%"><a href="http://aakshintala.com"><img src="https://avatars.githubusercontent.com/u/748697?v=4?s=80" width="80px;" alt="Amogh Akshintala"/><br /><sub><b>Amogh Akshintala</b></sub></a><br /><a href="https://github.com/tddworks/claudebar/commits?author=aakshintala" title="Code">💻</a></td>
      <td align="center" valign="top" width="16.66%"><a href="https://www.portfolio.isnakolah.me"><img src="https://avatars.githubusercontent.com/u/47239024?v=4?s=80" width="80px;" alt="Daniel Nakolah"/><br /><sub><b>Daniel Nakolah</b></sub></a><br /><a href="https://github.com/tddworks/claudebar/commits?author=isnakolah" title="Code">💻</a></td>
      <td align="center" valign="top" width="16.66%"><a href="https://github.com/Mitsi-ag"><img src="https://avatars.githubusercontent.com/u/141203898?v=4?s=80" width="80px;" alt="Mitsi-ag"/><br /><sub><b>Mitsi-ag</b></sub></a><br /><a href="https://github.com/tddworks/claudebar/commits?author=Mitsi-ag" title="Code">💻</a></td>
      <td align="center" valign="top" width="16.66%"><a href="https://www.josecancinolinares.com/en/portfolio"><img src="https://avatars.githubusercontent.com/u/65030646?v=4?s=80" width="80px;" alt="José Cancino Linares"/><br /><sub><b>José Cancino Linares</b></sub></a><br /><a href="https://github.com/tddworks/claudebar/commits?author=josecancino" title="Code">💻</a></td>
      <td align="center" valign="top" width="16.66%"><a href="https://github.com/logancox"><img src="https://avatars.githubusercontent.com/u/28828028?v=4?s=80" width="80px;" alt="logancox"/><br /><sub><b>logancox</b></sub></a><br /><a href="https://github.com/tddworks/claudebar/commits?author=logancox" title="Code">💻</a></td>
      <td align="center" valign="top" width="16.66%"><a href="http://ywmei.ca/index.php"><img src="https://avatars.githubusercontent.com/u/5897309?v=4?s=80" width="80px;" alt="y5mei"/><br /><sub><b>y5mei</b></sub></a><br /><a href="https://github.com/tddworks/claudebar/commits?author=y5mei" title="Code">💻</a></td>
    </tr>
    <tr>
      <td align="center" valign="top" width="16.66%"><a href="https://hansonkim.github.io"><img src="https://avatars.githubusercontent.com/u/1308073?v=4?s=80" width="80px;" alt="Hanson Kim"/><br /><sub><b>Hanson Kim</b></sub></a><br /><a href="https://github.com/tddworks/claudebar/commits?author=hansonkim" title="Code">💻</a></td>
    </tr>
  </tbody>
  <tfoot>
    <tr>
      <td align="center" size="13px" colspan="6">
        <img src="https://raw.githubusercontent.com/all-contributors/all-contributors-cli/1b8533af435da9854653492b1327a23a4dbd0a10/assets/logo-small.svg">
          <a href="https://all-contributors.js.org/docs/en/bot/usage">Add your contributions</a>
        </img>
      </td>
    </tr>
  </tfoot>
</table>

<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->

<!-- ALL-CONTRIBUTORS-LIST:END -->
<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->

This project follows the [all-contributors](https://github.com/all-contributors/all-contributors) specification. Contributions of any kind welcome!

To credit someone, comment on any issue or pull request:

```
@all-contributors please add @username for code, doc
```

## License

MIT
