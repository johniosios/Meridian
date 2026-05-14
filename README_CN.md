# HealthLens — iOS AI 健康助手

> 我没有任何 iOS 开发经验。用 Claude Code 写所有 Swift 代码，3 天做出了一个跑在自己手机上的 AI 健康助手。这是这个 App 的开源版本。

![Build](https://github.com/whwhw/HealthLens/actions/workflows/build.yml/badge.svg)

[English](README.md) · 中文

---

## 它能做什么

读取 Apple HealthKit 里的健康数据（睡眠、心率、HRV、步数、锻炼、体重），直接在手机上调用 Claude 或 OpenAI API 做 AI 分析。没有后端，没有第三方云，数据只存在你自己的 iCloud 里。

**功能**
- AI 健康洞察卡（7/14/30 天分析窗口）
- AI 生成健康提醒（不是 if/else 规则引擎，是模型真正看数据给建议）
- 6 张趋势图表（睡眠、HRV、静息心率、步数、活动能量、体重）
- 每日通知（带最新 AI 摘要）
- 全量历史 JSON 导出（iCloud Drive 自动同步到 Mac）
- iOS 快捷指令定时自动导出
- 免费 Apple 开发者账号可用（不需要 $99/年）

---

## 截图

<!-- 在这里放截图 -->

---

## 快速上手

**前置条件**
- Xcode 16+
- 有 Apple Watch 数据的 iPhone（没有 Watch 的话 HealthKit 数据会很少）
- [Anthropic](https://console.anthropic.com) 或 OpenAI 的 API Key

**步骤**

1. 克隆并在 Xcode 打开：
   ```bash
   git clone https://github.com/whwhw/HealthLens.git
   cd HealthLens
   open HealthLens.xcodeproj
   ```

2. Xcode → **Signing & Capabilities**：选你的 Team，把 Bundle ID 改成自己的（例如 `com.yourname.healthexport`）

3. iPhone 连 Mac，Xcode 左上角选你的手机，点 **▶ Run**

4. 首次启动时授权 HealthKit 读取权限

5. 进 **设置 → AI 分析**，填入 API Key

完成。在「今日」Tab 点「生成洞察」。

> **免费账号签名**：Xcode 每 7 天需要重签一次，App 失效时重新连手机点 Run 即可。

---

## iCloud Drive 同步（可选）

App 可以把每天的 JSON 文件导出到 iCloud Drive，自动同步到 Mac 供进一步分析（比如接入 AI agent）。

1. 进 **设置 → 导出存储 → 更改**
2. 选 iCloud Drive 下的某个文件夹（比如 `iCloud Drive/HealthLens/`）
3. App 保存一个 security-scoped bookmark，之后永久可写——不需要 iCloud Capability，免费账号完全可用

Mac 访问路径：`~/Library/Mobile Documents/com~apple~CloudDocs/HealthLens/`

JSON 格式说明：见 [`SPEC.md`](SPEC.md)

---

## 架构

```
HealthStore      — HealthKit 授权 + 查询（共享 EnvironmentObject）
    │
    ├── HomeDataLoader    — 今日 Tab 的指标聚合
    ├── ChartDataLoader   — 趋势 Tab 的时序数据
    ├── InsightGenerator  — 组装 Prompt + 调用 Claude/OpenAI API
    └── Orchestrator      — 导出流水线（日期范围 → JSON 文件）

APIClient        — HTTP 层，同时支持 Anthropic 和 OpenAI 兼容接口
APIConfig        — Provider / 模型 / Base URL / API Key（存 Keychain）
FolderStore      — iCloud Drive 目录选择（security-scoped bookmark）
```

`HealthStore` 在 `AppTabView` 统一创建，通过 `@EnvironmentObject` 注入全局。所有数据加载类以方法参数形式接收，没有隐藏的单例。

**零第三方依赖。** 纯 Apple 原生框架：SwiftUI · HealthKit · Charts · UserNotifications · AppIntents · Security。

---

## AI Provider 配置

默认使用 Anthropic Claude，可在设置里切换到任何 OpenAI 兼容 API：

| Provider | 默认模型 | 说明 |
|---|---|---|
| Anthropic | claude-opus-4-7 | 分析质量最好 |
| OpenAI | gpt-4o | |
| 自定义 | — | 任何 OpenAI 兼容接口 |

---

## 为什么做这个

Apple 健康 App 有数据，缺的是解读。我想要的不是一堆数字仪表盘，而是有人看完我最近 7 天的睡眠、HRV、步数之后，用一段话告诉我「这说明什么」——比如「恢复状态不错，但睡眠规律性在下降」。

顺带证明了一件事：一个不会 iOS 开发的人，用 AI 编程工具，周末可以做出一个真正能用的 iOS App。

---

## 参与贡献

见 [CONTRIBUTING.md](CONTRIBUTING.md)。

---

## 许可证

MIT — 见 [LICENSE](LICENSE)。
