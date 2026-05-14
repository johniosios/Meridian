<div align="center">
  <img src="assets/icon.png" width="120" alt="HealthLens icon" />
  <h1>HealthLens</h1>
  <p>AI health analysis from your Apple Watch — private, on-device, no backend.</p>

  <p>
    <a href="https://github.com/whwhw/HealthLens/actions/workflows/build.yml">
      <img src="https://github.com/whwhw/HealthLens/actions/workflows/build.yml/badge.svg" alt="Build" />
    </a>
    <img src="https://img.shields.io/badge/platform-iOS%2017%2B-blue?logo=apple" alt="Platform" />
    <img src="https://img.shields.io/badge/swift-5.9%2B-orange?logo=swift" alt="Swift" />
    <img src="https://img.shields.io/badge/license-MIT-green" alt="License" />
    <img src="https://img.shields.io/badge/dependencies-none-lightgrey" alt="No dependencies" />
  </p>

  <p>English &nbsp;·&nbsp; <a href="README_CN.md">中文</a></p>
</div>

---

## Screenshots

<div align="center">
  <img src="assets/screenshot-home.png" width="30%" alt="Home — AI insight card" />
  &nbsp;&nbsp;
  <img src="assets/screenshot-charts.png" width="30%" alt="Charts — trend view" />
  &nbsp;&nbsp;
  <img src="assets/screenshot-settings.png" width="30%" alt="Settings" />
</div>


---

## Features

| | |
|---|---|
| 🧠 **AI Health Insight** | Claude or GPT-4o reads your last 7/14/30 days and writes a plain-language summary |
| 🔔 **Smart Alerts** | Model-generated alerts — not if/else rules, actual judgment on your patterns |
| 📈 **Trend Charts** | Sleep · HRV · Resting HR · Steps · Active Energy · Weight |
| ☁️ **iCloud Export** | Daily JSON export syncs to Mac automatically, no iCloud capability required |
| ⏰ **Shortcuts Automation** | Register once in iOS Shortcuts, export runs every night |
| 🔐 **Private by design** | API key in Keychain · data stays in your iCloud · no account, no backend |
| 💸 **Free account** | Works with a free Apple developer account — no $99/year needed |

---

## Quick start

**Requirements:** Xcode 16+ · iPhone with Apple Watch data · Anthropic or OpenAI API key

```bash
git clone https://github.com/whwhw/HealthLens.git
cd HealthLens
open HealthExport.xcodeproj
```

1. **Xcode → Signing & Capabilities** — set your Team, change Bundle ID to `com.yourname.healthlens`
2. Connect iPhone → select it as target → **▶ Run**
3. Grant HealthKit permissions on first launch
4. **Settings → AI Analysis** — paste your API key
5. Tap **Generate Insight** on the Home tab

> **Free account re-signing**: Xcode re-signs every 7 days. Reconnect and hit Run when it expires.

---

## iCloud Drive sync

Export daily JSON files to iCloud Drive for Mac-side analysis (e.g. feeding an AI agent).

1. **Settings → Export Storage → Change** — pick a folder inside iCloud Drive
2. App saves a security-scoped bookmark — works on free accounts, no iCloud Capability needed
3. Files appear at `~/Library/Mobile Documents/com~apple~CloudDocs/<your-folder>/`

Schema: see [`SPEC.md`](SPEC.md)

---

## Personal AI health assistant (advanced)

Once your health data is syncing to Mac, you can wire it into any local AI agent — giving it real-time awareness of your body state alongside your calendar, notes, or work context.

### How it works

```
iPhone HealthKit
  ↓  HealthLens exports daily JSON
iCloud Drive  ──sync──▶  Mac ~/Library/Mobile Documents/.../
                              ↓
                         AI Agent reads last N days
                              ↓
                    "Should I train hard today?"
                    "Why was my HRV low this week?"
                    "Best time to do deep work this afternoon?"
```

The agent answers by combining your health data with whatever else it knows — meeting notes, mood logs, project state. Health data becomes one more sensor, not a separate app.

### Step 1 — find your sync path

After picking an iCloud folder in the app, the files land at:

```bash
~/Library/Mobile\ Documents/com~apple~CloudDocs/<your-folder>/
# e.g.
~/Library/Mobile\ Documents/com~apple~CloudDocs/HealthLens/
```

Verify with:

```bash
ls ~/Library/Mobile\ Documents/com~apple~CloudDocs/HealthLens/ | tail -5
# 2026-05-10.json
# 2026-05-11.json
# 2026-05-12.json
# 2026-05-13.json
# 2026-05-14.json
```

### Step 2 — read health data in your agent

A minimal Python helper that any agent can call:

```python
import json, os
from datetime import date, timedelta
from pathlib import Path

HEALTH_DIR = Path.home() / "Library/Mobile Documents/com~apple~CloudDocs/HealthLens"

def read_health(days: int = 7) -> list[dict]:
    """Return the last N days of health snapshots, newest first."""
    snapshots = []
    for i in range(days):
        d = date.today() - timedelta(days=i)
        path = HEALTH_DIR / f"{d}.json"
        if path.exists():
            snapshots.append(json.loads(path.read_text()))
    return snapshots

def health_summary(days: int = 7) -> str:
    """One-liner summary for injecting into a system prompt."""
    data = read_health(days)
    if not data:
        return "No health data available."
    lines = []
    for s in data:
        parts = [s["date"]]
        if s.get("sleep", {}).get("asleep_minutes"):
            parts.append(f"sleep {s['sleep']['asleep_minutes']//60}h{s['sleep']['asleep_minutes']%60}m")
        if s.get("heart", {}).get("hrv_sdnn_ms"):
            parts.append(f"HRV {s['heart']['hrv_sdnn_ms']:.0f}ms")
        if s.get("heart", {}).get("resting_bpm"):
            parts.append(f"RHR {s['heart']['resting_bpm']}bpm")
        if s.get("activity", {}).get("steps"):
            parts.append(f"steps {s['activity']['steps']:,}")
        lines.append("  " + " · ".join(parts))
    return "Recent health data:\n" + "\n".join(lines)
```

### Step 3 — inject into your agent's system prompt

```python
system_prompt = f"""
You are a personal assistant with full context about the user.

{health_summary(days=7)}

Use this data to inform advice about energy, focus, training, and recovery.
Never surface raw numbers unless asked — interpret them instead.
"""
```

### Step 4 — example queries that now work

| Query | What the agent uses |
|---|---|
| "Should I do a hard workout today?" | HRV trend + resting HR vs baseline |
| "Why have I been tired this week?" | Sleep duration + consistency over 7 days |
| "Best time for deep work this afternoon?" | Last night's sleep quality |
| "Am I overtraining?" | HRV decline + active energy over 14 days |

### Works with any agent framework

- **Claude Code** — add `read_health()` as a tool in your `CLAUDE.md`
- **MCP server** — expose `read_health` as an MCP resource
- **LangChain / LlamaIndex** — wrap as a `Tool` with the helper above
- **Any local agent** — call `health_summary()` at conversation start

---

## Architecture

```
AppTabView
└── @EnvironmentObject: HealthStore, APIConfig, FolderStore, NotificationManager
    │
    ├── HomeView
    │   ├── HomeDataLoader   — metrics + mini-trends (receives HealthStore as param)
    │   └── InsightGenerator — prompt builder + Claude/OpenAI call
    │
    ├── ChartsView
    │   └── ChartDataLoader  — 6 time-series (receives HealthStore as param)
    │
    ├── ContentView (Export tab)
    │   └── Orchestrator     — date range → JSON pipeline
    │
    └── SettingsView
        └── APIConfig · FolderStore · NotificationManager
```

`HealthStore` is created **once** at the root and injected via `@EnvironmentObject`. No hidden singletons — all data-loading classes receive it as a method parameter.

**Zero third-party dependencies** — SwiftUI · HealthKit · Charts · UserNotifications · AppIntents · Security

---

## AI providers

Default is Anthropic Claude. Switch in Settings to any OpenAI-compatible endpoint:

| Provider | Default model | |
|---|---|---|
| Anthropic | `claude-opus-4-7` | Recommended |
| OpenAI | `gpt-4o` | |
| Custom | any | OpenAI-compatible base URL |

---

## Why I built this

Apple Health has the data. What it lacks is interpretation.

I wanted something that looks at 7 days of sleep + HRV + steps and tells me *what it means* in plain language — not a dashboard of numbers, but "your recovery looks good, but sleep consistency is dropping."

Built in 3 days with zero prior Swift experience, using Claude Code to write all the code.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). One concern per PR, test on real device, keep zero-dependency rule.

---

## License

MIT — see [LICENSE](LICENSE).
