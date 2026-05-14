<div align="center">
  <img src="assets/icon.png" width="120" alt="HealthLens 图标" />
  <h1>HealthLens</h1>
  <p>基于 Apple Watch 数据的 AI 健康分析 — 私密、本地、无后端。</p>

  <p>
    <a href="https://github.com/whwhw/HealthLens/actions/workflows/build.yml">
      <img src="https://github.com/whwhw/HealthLens/actions/workflows/build.yml/badge.svg" alt="Build" />
    </a>
    <img src="https://img.shields.io/badge/platform-iOS%2017%2B-blue?logo=apple" alt="Platform" />
    <img src="https://img.shields.io/badge/swift-5.9%2B-orange?logo=swift" alt="Swift" />
    <img src="https://img.shields.io/badge/license-MIT-green" alt="License" />
    <img src="https://img.shields.io/badge/dependencies-none-lightgrey" alt="No dependencies" />
  </p>

  <p><a href="README.md">English</a> &nbsp;·&nbsp; 中文</p>
</div>

---

## 截图

<div align="center">
  <img src="assets/screenshot-home.png" width="30%" alt="今日 — AI 洞察卡" />
  &nbsp;&nbsp;
  <img src="assets/screenshot-charts.png" width="30%" alt="趋势图表" />
  &nbsp;&nbsp;
  <img src="assets/screenshot-settings.png" width="30%" alt="设置" />
</div>


---

## 功能

| | |
|---|---|
| 🧠 **AI 健康洞察** | Claude 或 GPT-4o 读取最近 7/14/30 天数据，生成白话文分析摘要 |
| 🔔 **智能提醒** | AI 生成健康提醒，不是 if/else 规则引擎，是模型真正分析你的数据规律 |
| 📈 **趋势图表** | 睡眠 · HRV · 静息心率 · 步数 · 活动能量 · 体重 |
| ☁️ **iCloud 导出** | 每日 JSON 文件自动同步到 Mac，无需 iCloud Capability |
| ⏰ **快捷指令自动化** | iOS 快捷指令注册一次，每晚自动导出 |
| 🔐 **隐私优先** | API Key 存 Keychain · 数据只在你的 iCloud · 无账号无后端 |
| 💸 **免费账号可用** | 无需 $99/年 Apple 开发者订阅 |

---

## 快速上手

**前置条件：** Xcode 16+ · 有 Apple Watch 数据的 iPhone · Anthropic 或 OpenAI 的 API Key

```bash
git clone https://github.com/whwhw/HealthLens.git
cd HealthLens
open HealthExport.xcodeproj
```

1. **Xcode → Signing & Capabilities** — 选你的 Team，Bundle ID 改成 `com.yourname.healthlens`
2. 连接 iPhone → 选为运行目标 → **▶ Run**
3. 首次启动授权 HealthKit 权限
4. **设置 → AI 分析** — 填入 API Key
5. 在「今日」Tab 点「生成洞察」

> **免费账号重签**：Xcode 每 7 天重签一次。App 失效时重新连手机点 Run 即可。

---

## iCloud Drive 同步

将每日 JSON 文件导出到 iCloud Drive，Mac 端可直接读取做进一步分析（比如接入 AI agent）。

1. **设置 → 导出存储 → 更改** — 选 iCloud Drive 下的目录
2. App 保存 security-scoped bookmark，免费账号完全可用，不需要 iCloud Capability
3. Mac 访问路径：`~/Library/Mobile Documents/com~apple~CloudDocs/<你选的目录>/`

JSON 格式：见 [`SPEC.md`](SPEC.md)

---

## 打造个人 AI 健康助手（进阶）

健康数据同步到 Mac 之后，可以接入任意本地 AI agent，让它实时感知你的身体状态——结合日历、笔记、工作上下文，给出真正个性化的建议。

### 整体链路

```
iPhone HealthKit
  ↓  HealthLens 每日导出 JSON
iCloud Drive  ──自动同步──▶  Mac ~/Library/Mobile Documents/.../
                                    ↓
                             AI Agent 读取最近 N 天
                                    ↓
                      「今天适合高强度训练吗？」
                      「这周 HRV 为什么低？」
                      「今天下午什么时候适合深度工作？」
```

Agent 综合你的健康数据 + 其他上下文（日报、情绪、项目进展）来回答，健康数据变成 agent 的一个感知维度，而不是孤立的 App。

### 第一步 — 确认同步路径

在 App 设置里选好 iCloud 目录后，文件会出现在：

```bash
~/Library/Mobile\ Documents/com~apple~CloudDocs/<你的目录>/
# 例如
~/Library/Mobile\ Documents/com~apple~CloudDocs/HealthLens/
```

验证：

```bash
ls ~/Library/Mobile\ Documents/com~apple~CloudDocs/HealthLens/ | tail -5
# 2026-05-10.json
# 2026-05-11.json
# ...
```

### 第二步 — 在 agent 里读取健康数据

一个任何 agent 都能直接调用的 Python 工具：

```python
import json, os
from datetime import date, timedelta
from pathlib import Path

HEALTH_DIR = Path.home() / "Library/Mobile Documents/com~apple~CloudDocs/HealthLens"

def read_health(days: int = 7) -> list[dict]:
    """返回最近 N 天的健康数据，最新的在前。"""
    snapshots = []
    for i in range(days):
        d = date.today() - timedelta(days=i)
        path = HEALTH_DIR / f"{d}.json"
        if path.exists():
            snapshots.append(json.loads(path.read_text()))
    return snapshots

def health_summary(days: int = 7) -> str:
    """生成一段文字，可直接注入 system prompt。"""
    data = read_health(days)
    if not data:
        return "暂无健康数据。"
    lines = []
    for s in data:
        parts = [s["date"]]
        if s.get("sleep", {}).get("asleep_minutes"):
            parts.append(f"睡眠 {s['sleep']['asleep_minutes']//60}h{s['sleep']['asleep_minutes']%60}m")
        if s.get("heart", {}).get("hrv_sdnn_ms"):
            parts.append(f"HRV {s['heart']['hrv_sdnn_ms']:.0f}ms")
        if s.get("heart", {}).get("resting_bpm"):
            parts.append(f"静息心率 {s['heart']['resting_bpm']}bpm")
        if s.get("activity", {}).get("steps"):
            parts.append(f"步数 {s['activity']['steps']:,}")
        lines.append("  " + " · ".join(parts))
    return "最近健康数据：\n" + "\n".join(lines)
```

### 第三步 — 注入 system prompt

```python
system_prompt = f"""
你是用户的个人助手，掌握用户的完整上下文。

{health_summary(days=7)}

根据以上数据为用户提供关于精力、专注力、训练和恢复的建议。
除非用户主动询问，不要直接罗列原始数字——给出解读。
"""
```

### 第四步 — 现在可以问的问题

| 问题 | Agent 使用的数据 |
|---|---|
| 今天适合高强度训练吗？ | HRV 趋势 + 静息心率与基线对比 |
| 这周为什么一直很累？ | 7 天睡眠时长 + 规律性 |
| 今天下午什么时候适合深度工作？ | 昨晚睡眠质量 |
| 我是不是过度训练了？ | 14 天 HRV 下降趋势 + 活动能量 |

### 兼容任意 agent 框架

- **Claude Code** — 在 `CLAUDE.md` 里把 `read_health()` 声明为工具
- **MCP server** — 将 `read_health` 暴露为 MCP resource
- **LangChain / LlamaIndex** — 封装成 `Tool`
- **任意本地 agent** — 对话开始时调用 `health_summary()` 注入上下文

---

## 架构

```
AppTabView
└── @EnvironmentObject: HealthStore, APIConfig, FolderStore, NotificationManager
    │
    ├── HomeView（今日）
    │   ├── HomeDataLoader   — 指标聚合 + 迷你趋势（接收 HealthStore 参数）
    │   └── InsightGenerator — 组装 Prompt + 调用 Claude/OpenAI
    │
    ├── ChartsView（趋势）
    │   └── ChartDataLoader  — 6 条时序数据（接收 HealthStore 参数）
    │
    ├── ContentView（导出）
    │   └── Orchestrator     — 日期范围 → JSON 文件流水线
    │
    └── SettingsView（设置）
        └── APIConfig · FolderStore · NotificationManager
```

`HealthStore` 在根节点统一创建，通过 `@EnvironmentObject` 注入全局。所有数据加载类以方法参数接收，无隐藏单例。

**零第三方依赖** — SwiftUI · HealthKit · Charts · UserNotifications · AppIntents · Security

---

## AI Provider 配置

默认 Anthropic Claude，可在设置里切换到任何 OpenAI 兼容接口：

| Provider | 默认模型 | |
|---|---|---|
| Anthropic | `claude-opus-4-7` | 推荐 |
| OpenAI | `gpt-4o` | |
| 自定义 | 任意 | OpenAI 兼容的 base URL |

---

## 为什么做这个

Apple 健康 App 有数据，缺的是解读。

我想要的不是数字仪表盘，而是有人看完我 7 天的睡眠、HRV、步数之后，用一段话告诉我「这说明什么」——比如「恢复状态不错，但睡眠规律性在下降」。

0 iOS 经验，用 Claude Code 写所有 Swift 代码，3 天做出来的。

---

## 参与贡献

见 [CONTRIBUTING.md](CONTRIBUTING.md)。每个 PR 只做一件事，真机测试，保持零依赖。

---

## 许可证

MIT — 见 [LICENSE](LICENSE)。
