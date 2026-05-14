# Contributing

## Before you start

This is a personal tool open-sourced in the spirit of sharing. Contributions are welcome but scope is intentionally narrow — this app does one thing: read HealthKit data and show AI analysis. PRs that add significant complexity will likely be declined.

## What's welcome

- Bug fixes
- Support for additional HealthKit data types
- Localization (the UI is currently Chinese)
- Documentation improvements
- Alternative AI provider support (the `APIClient` is already extensible)

## Setup

1. Clone the repo
2. Open `HealthLens.xcodeproj` in Xcode
3. Set your own Bundle ID and Team under **Signing & Capabilities**
4. Add your API key in **Settings → AI Analysis** after first launch

No third-party dependencies — pure Apple frameworks only.

## Architecture

```
HealthStore      — HealthKit authorization + queries (shared EnvironmentObject)
APIClient        — Claude / OpenAI-compatible HTTP calls
APIConfig        — Provider, model, base URL, API key (Keychain)
InsightGenerator — Prompt construction + response parsing
HomeDataLoader   — Metrics aggregation for Home tab
ChartDataLoader  — Time-series data for Charts tab
Orchestrator     — Export pipeline (date range → JSON files)
FolderStore      — iCloud Drive folder selection via security-scoped bookmark
```

Data flow: `HealthStore` → loader/generator → View via `@EnvironmentObject`.

## Submitting a PR

- One concern per PR
- Test on a real device (HealthKit does not work in Simulator)
- Keep the zero-third-party-dependency rule
