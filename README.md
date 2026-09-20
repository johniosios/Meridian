# Meridian

Private, on-device AI analysis of your Apple Health data. No backend, no account, no data leaving your iCloud.

<div align="center">
  <img src="assets/icon.png" width="160" alt="Meridian" />
</div>

| | Feature |
|:---:|---|
| 🧠 | **AI Insight** — Claude or GPT-4o summarizes your last 7 / 14 / 30 days in plain language |
| 🔔 | **Smart Alerts** — model-generated, not hand-written if/else rules |
| 📈 | **Trend Charts** — Sleep · HRV · Resting HR · Steps · Active Energy · Weight |
| ☁️ | **iCloud Export** — daily JSON syncs to Mac automatically |
| ⏰ | **Shortcuts Automation** — set once, runs every night |
| 🔐 | **Private by design** — API key in Keychain, data stays in your iCloud |

---

## Quick start

> Requires Xcode 16+ · iPhone with Apple Watch data · API key from [Anthropic](https://console.anthropic.com) or OpenAI

```bash
open Meridian.xcodeproj
```

1. **Signing & Capabilities** — set your Team and Bundle ID
2. Connect iPhone → **▶ Run**
3. Grant HealthKit permissions on first launch
4. **Settings → AI Analysis** → paste your API key
5. Tap **Generate Insight**

> **Free account note:** Xcode re-signs every 7 days. Reconnect and hit Run again when the app expires.

---

## iCloud Drive sync

Export daily JSON snapshots to iCloud Drive — they auto-sync to your Mac for deeper analysis or AI agent integration.

1. **Settings → Export Storage → Change** — pick any iCloud Drive folder
2. App stores a security-scoped bookmark (no iCloud Capability required)
3. Files land at `~/Library/Mobile Documents/com~apple~CloudDocs/<folder>/`

---

## Use as an AI agent data source

Once data is on your Mac, any AI agent can read it and answer questions like:

> *"Should I train hard today?"* &nbsp; *"Why have I been tired this week?"* &nbsp; *"Best time for deep work this afternoon?"*

<details>
<summary><b>Integration guide (Python · MCP)</b></summary>

<br/>

**How it works**

```
iPhone HealthKit
  ↓  Meridian exports daily JSON
iCloud Drive ──sync──▶ Mac ~/Library/Mobile Documents/.../
                             ↓
                        AI Agent reads last N days
                             ↓
              answers grounded in your actual body data
```

**Step 1 — verify your sync path**

```bash
ls ~/Library/Mobile\ Documents/com~apple~CloudDocs/Meridian/ | tail -5
# 2026-05-10.json  2026-05-11.json  ...  2026-05-14.json
```

**Step 2 — Python helper**

```python
import json
from datetime import date, timedelta
from pathlib import Path

HEALTH_DIR = Path.home() / "Library/Mobile Documents/com~apple~CloudDocs/Meridian"

def read_health(days: int = 7) -> list[dict]:
    snapshots = []
    for i in range(days):
        d = date.today() - timedelta(days=i)
        p = HEALTH_DIR / f"{d}.json"
        if p.exists():
            snapshots.append(json.loads(p.read_text()))
    return snapshots

def health_summary(days: int = 7) -> str:
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

**Step 3 — inject into system prompt**

```python
system_prompt = f"""
You are a personal assistant with full context about the user.

{health_summary(days=7)}

Use this to inform advice about energy, focus, training, and recovery.
Interpret patterns — don't just repeat raw numbers.
"""
```

**Works with any framework**

| Framework | How |
|---|---|
| MCP server | Expose `read_health` as an MCP resource |
| LangChain / LlamaIndex | Wrap as a `Tool` |
| Any local agent | Call `health_summary()` at conversation start |

</details>

---

## Architecture

<details>
<summary><b>Show architecture diagram</b></summary>

<br/>

```
AppTabView
└── @EnvironmentObject: HealthStore · APIConfig · FolderStore · NotificationManager
    │
    ├── HomeView
    │   ├── HomeDataLoader   — metrics + mini-trends
    │   └── InsightGenerator — prompt builder + API call
    │
    ├── ChartsView
    │   └── ChartDataLoader  — 6 time-series charts
    │
    ├── ExportView (Export tab)
    │   └── Orchestrator     — date range → JSON pipeline
    │
    └── SettingsView
```

`HealthStore` is created **once** at the root and passed as a method parameter to all data-loading classes — no hidden singletons.

**Zero third-party dependencies** — SwiftUI · HealthKit · Charts · UserNotifications · AppIntents · Security

</details>

---

## AI providers

| Provider | Default model | Note |
|---|---|---|
| **Anthropic** | `claude-opus-4-7` | Recommended |
| **OpenAI** | `gpt-4o` | |
| **Custom** | any | OpenAI-compatible base URL — works with DeepSeek, Ollama, etc. |

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE)
