<div align="center">
  <img src="assets/icon.png" width="160" alt="HealthLens" /><br/><br/>
  <h2>HealthLens</h2>
  <p><b>AI health analysis from your Apple Watch.</b><br/>Private · On-device · No backend · No account.</p>

  <p>
    <a href="https://github.com/whwhw/HealthLens/actions/workflows/build.yml">
      <img src="https://github.com/whwhw/HealthLens/actions/workflows/build.yml/badge.svg?style=flat-square" alt="Build" />
    </a>
    &nbsp;
    <img src="https://img.shields.io/badge/iOS-17%2B-007AFF?style=flat-square&logo=apple&logoColor=white" />
    &nbsp;
    <img src="https://img.shields.io/badge/Swift-5.9%2B-FA7343?style=flat-square&logo=swift&logoColor=white" />
    &nbsp;
    <img src="https://img.shields.io/badge/License-MIT-34C759?style=flat-square" />
    &nbsp;
    <img src="https://img.shields.io/badge/Dependencies-Zero-8E8E93?style=flat-square" />
  </p>

  <p>
    <a href="README_CN.md">中文文档</a>
  </p>
</div>

<br/>

<div align="center">
  <img src="assets/screenshot-home.png" width="28%" />
  &nbsp;&nbsp;&nbsp;
  <img src="assets/screenshot-charts.png" width="28%" />
  &nbsp;&nbsp;&nbsp;
  <img src="assets/screenshot-settings.png" width="28%" />
  <br/>
  <sub>Home · Trends · Settings</sub>
</div>

<br/>

---

## What it does

HealthLens reads your Apple Watch data from HealthKit and runs AI analysis **entirely on your device** — no server, no account, no data leaves your iCloud.

| | Feature |
|:---:|---|
| 🧠 | **AI Insight** — Claude or GPT-4o summarizes your last 7 / 14 / 30 days in plain language |
| 🔔 | **Smart Alerts** — model-generated, not hand-written if/else rules |
| 📈 | **Trend Charts** — Sleep · HRV · Resting HR · Steps · Active Energy · Weight |
| ☁️ | **iCloud Export** — daily JSON syncs to Mac automatically |
| ⏰ | **Shortcuts Automation** — set once, runs every night |
| 🔐 | **Private by design** — API key in Keychain, data stays in your iCloud |
| 💸 | **Free account** — no $99/year Apple Developer subscription needed |

---

## Quick start

> Requires Xcode 16+ · iPhone with Apple Watch data · API key from [Anthropic](https://console.anthropic.com) or OpenAI

```bash
git clone https://github.com/whwhw/HealthLens.git
open HealthExport.xcodeproj
```

1. **Signing & Capabilities** — set your Team, change Bundle ID to `com.yourname.healthlens`
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

→ See [`SPEC.md`](SPEC.md) for the full JSON schema.

---

## Use as an AI agent data source

Once data is on your Mac, any AI agent can read it and answer questions like:

> *"Should I train hard today?"* &nbsp; *"Why have I been tired this week?"* &nbsp; *"Best time for deep work this afternoon?"*

<details>
<summary><b>Integration guide (Python · Claude Code · MCP)</b></summary>

<br/>

**How it works**

```
iPhone HealthKit
  ↓  HealthLens exports daily JSON
iCloud Drive ──sync──▶ Mac ~/Library/Mobile Documents/.../
                             ↓
                        AI Agent reads last N days
                             ↓
              answers grounded in your actual body data
```

**Step 1 — verify your sync path**

```bash
ls ~/Library/Mobile\ Documents/com~apple~CloudDocs/HealthLens/ | tail -5
# 2026-05-10.json  2026-05-11.json  ...  2026-05-14.json
```

**Step 2 — Python helper**

```python
import json
from datetime import date, timedelta
from pathlib import Path

HEALTH_DIR = Path.home() / "Library/Mobile Documents/com~apple~CloudDocs/HealthLens"

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
| Claude Code | Add `read_health()` as a tool in `CLAUDE.md` |
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
    ├── ContentView (Export tab)
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

## Why I built this

Apple Health has the data. What it lacks is interpretation.

I wanted something that looks at 7 days of my sleep + HRV + steps and tells me *what it means* — not a dashboard of numbers, but a paragraph that says *"your recovery is solid but sleep consistency is slipping."*

Also wanted to prove a non-iOS developer can ship a real iOS app in a weekend with AI coding tools. **Built in 3 days with zero prior Swift experience**, using Claude Code to write all the Swift.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) — one concern per PR, test on real device, keep zero-dependency rule.

## License

[MIT](LICENSE)
