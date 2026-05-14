# HealthLens — AI Health Assistant for iOS

> I had zero iOS experience. In 3 days, using Claude Code to write all the Swift, I built an AI health assistant running on my own iPhone. This is that app, open-sourced.

![Build](https://github.com/whwhw/HealthLens/actions/workflows/build.yml/badge.svg)

English · [中文](README_CN.md)

---

## What it does

Reads your Apple HealthKit data (sleep, heart rate, HRV, steps, workouts, body metrics) and runs AI analysis directly on-device via the Claude or OpenAI API. No backend, no cloud, your data stays in your iCloud.

**Features**
- AI insight card with 7/14/30-day analysis window
- AI-generated health alerts (not rule-based if/else — actual model judgment)
- 6 trend charts (sleep, HRV, resting HR, steps, active energy, weight)
- Daily notification with cached AI summary
- Full history export to JSON (iCloud Drive sync)
- iOS Shortcuts automation for scheduled export
- Works with a free Apple developer account (no $99/year required)

---

## Screenshots

<!-- Add screenshots here -->

---

## Quick start

**Requirements**
- Xcode 16+
- iPhone with Apple Watch data (HealthKit won't have much without it)
- API key from [Anthropic](https://console.anthropic.com) or OpenAI

**Steps**

1. Clone and open in Xcode:
   ```bash
   git clone https://github.com/whwhw/HealthLens.git
   cd HealthLens
   open HealthLens.xcodeproj
   ```

2. In Xcode → **Signing & Capabilities**: set your Team and change the Bundle ID to something unique (e.g. `com.yourname.healthexport`)

3. Connect your iPhone, select it as the run target, hit **▶ Run**

4. On first launch, grant HealthKit permissions when prompted

5. Go to **Settings → AI Analysis**, enter your API key

That's it. Tap **Generate Insight** on the home tab.

> **Free account signing**: Xcode will re-sign every 7 days. Reconnect and hit Run again when the app stops launching.

---

## iCloud Drive sync (optional)

The app can export daily JSON files to iCloud Drive, which then sync to your Mac for further analysis.

1. Go to **Settings → Export Storage → Change**
2. Pick a folder inside iCloud Drive (e.g. `iCloud Drive/HealthLens/`)
3. The app saves a security-scoped bookmark — no iCloud capability required, works on free accounts

Mac path: `~/Library/Mobile Documents/com~apple~CloudDocs/HealthLens/`

JSON schema: see [`SPEC.md`](SPEC.md)

---

## Architecture

```
HealthStore      — HealthKit auth + queries (shared EnvironmentObject)
    │
    ├── HomeDataLoader    — metrics aggregation for Home tab
    ├── ChartDataLoader   — time-series for Charts tab
    ├── InsightGenerator  — prompt + Claude/OpenAI API call
    └── Orchestrator      — export pipeline (date range → JSON files)

APIClient        — HTTP, handles Anthropic + OpenAI-compatible endpoints
APIConfig        — provider / model / base URL / API key (stored in Keychain)
FolderStore      — iCloud Drive folder via security-scoped bookmark
```

`HealthStore` is created once in `AppTabView` and injected as `@EnvironmentObject`. All data-loading classes receive it as a method parameter — no hidden singletons.

**Zero third-party dependencies.** SwiftUI · HealthKit · Charts · UserNotifications · AppIntents · Security framework only.

---

## AI provider

The app ships with Anthropic Claude as default. Switch to any OpenAI-compatible API in Settings:

| Provider | Default model | Notes |
|---|---|---|
| Anthropic | claude-opus-4-7 | Best analysis quality |
| OpenAI | gpt-4o | |
| Custom | — | Any OpenAI-compatible endpoint |

---

## Why I built this

Apple Health has the data. What it lacks is interpretation. I wanted something that looks at 7 days of my sleep + HRV + steps and tells me *what it means* — not a dashboard of numbers, but a short paragraph saying "your recovery looks good, but sleep consistency is dropping."

I also wanted to prove that a non-iOS developer can ship a real iOS app in a weekend using AI coding tools. This repo is the proof.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

---

## License

MIT — see [LICENSE](LICENSE).
