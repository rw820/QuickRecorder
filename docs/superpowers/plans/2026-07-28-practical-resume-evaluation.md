# Practical Resume Evaluation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让四项简历初评包含更多实际判断，同时删除重复套话。

**Architecture:** 修改简历初评提示词，让模型生成每项 60～100 字的具体内容；修改现有本地格式化器，清理指定套话并将上限调整为 100 字。刷新服务和界面不变。

**Tech Stack:** Swift 6、Swift Testing、Codex CLI

## Global Constraints

- 总评、优势、劣势、风险每部分控制在 60～100 个字符。
- 删除“仅为简历初评”“待面试验证”“简历声明”等重复套话。
- 建议问题继续固定生成 5 个。
- 不改变实时建议和最终面试评价。

---

### Task 1: 优化简历初评内容

**Files:**
- Modify: `InterviewAssistant/Tests/InterviewAssistantTests/AnalysisPromptTests.swift`
- Modify: `InterviewAssistant/Sources/InterviewAssistantCore/Intelligence/AnalysisPrompts.swift`
- Modify: `InterviewAssistant/Sources/InterviewAssistantCore/Intelligence/CompactResumeEvaluation.swift`

**Interfaces:**
- Consumes: Codex 返回的五段 Markdown 初评。
- Produces: `CompactResumeEvaluation.normalize(_:) -> InterviewEvaluation?`，四项评价不超过 100 字且不含指定套话。

- [ ] **Step 1: 写失败测试**

在 `AnalysisPromptTests` 中断言提示词包含“60 至 100 个字符”和套话禁令；构造带有套话及 120 字正文的 Markdown，断言规范化后每项不超过 100 字且不含“仅为简历初评”“待面试验证”“简历声明”。

- [ ] **Step 2: 运行测试确认失败**

Run: `swift run --package-path InterviewAssistant InterviewAssistantTests`

Expected: 字数或套话断言失败。

- [ ] **Step 3: 修改提示词和格式化器**

提示词明确要求四部分各 60～100 字、直接写具体结论并禁用三类套话。格式化器将 `compact` 上限从 50 调整为 100，并在压缩空白前移除：

```swift
["仅为简历初评", "待面试验证", "简历声明"]
```

清理后同时去除残留的中文逗号、句号和冒号。

- [ ] **Step 4: 运行完整测试和正式构建**

Run: `swift run --package-path InterviewAssistant InterviewAssistantTests`

Expected: 全部测试通过。

Run: `swift build --package-path InterviewAssistant -c release`

Expected: 正式构建成功。

- [ ] **Step 5: 安装并打开**

Run:

```bash
zsh InterviewAssistant/scripts/build-app.sh
ditto InterviewAssistant/.build/app/面试助手.app /Users/ben/Applications/面试助手.app
open /Users/ben/Applications/面试助手.app
```

Expected: 新版本应用启动，点击“刷新评价和问题”后生成更具体的四项初评。

- [ ] **Step 6: 提交**

```bash
git add InterviewAssistant
git commit -m "feat: make resume evaluation more practical"
```
