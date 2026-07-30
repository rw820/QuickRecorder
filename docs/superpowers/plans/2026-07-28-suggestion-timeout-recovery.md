# 追问建议超时恢复 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 追问生成首次超时时自动重试一次，并将单次等待时间提高到 30 秒。

**Architecture:** 超时仍由 `CodexCLIProvider` 负责判定，`InterviewIntelligencePipeline` 识别 `CodexCLIProviderError.timedOut` 并进行一次受控重试。现有 `suggestionTask` 继续保证同一时间只有一个追问任务。

**Tech Stack:** Swift 6、Swift Concurrency、自定义轻量测试框架。

## Global Constraints

- 单次追问超时为 30 秒。
- 只重试超时错误，最多重试一次。
- 第一次超时不发布失败警告。
- 不清空已有追问，不增加并发请求。

---

### Task 1: 增加超时重试测试

**Files:**
- Modify: `InterviewAssistant/Tests/InterviewAssistantTests/InterviewIntelligencePipelineTests.swift`

**Interfaces:**
- Consumes: `InterviewAnalysisProvider.generateSuggestions(from:resumeText:)`
- Produces: 可模拟“首次超时、第二次成功”和“非超时直接失败”的测试 Provider

- [ ] **Step 1: 写失败测试**

增加一个 Provider，首次调用抛出 `CodexCLIProviderError.timedOut`，第二次返回建议；断言调用次数为 2、最终没有追问失败警告。再增加非超时错误测试，断言调用次数为 1。

- [ ] **Step 2: 运行测试确认失败**

Run: `swift run --package-path InterviewAssistant InterviewAssistantTests`

Expected: 首次超时的建议调用次数为 1，测试失败。

### Task 2: 实现一次超时重试

**Files:**
- Modify: `InterviewAssistant/Sources/InterviewAssistantCore/Intelligence/InterviewIntelligencePipeline.swift`
- Modify: `InterviewAssistant/Sources/InterviewAssistantCore/Intelligence/CodexCLIProvider.swift`

**Interfaces:**
- Consumes: `CodexCLIProviderError.timedOut`
- Produces: `generateSuggestions(from:)` 最多调用 Provider 两次

- [ ] **Step 1: 将追问超时改为 30 秒**

把 `CodexCLIProvider.generateSuggestions` 的 `timeout: 20` 改为 `timeout: 30`。

- [ ] **Step 2: 增加超时识别**

在 Pipeline 内增加只匹配 `CodexCLIProviderError.timedOut` 的判断，首次超时后发布“追问生成较慢，正在重试”状态并重试一次。

- [ ] **Step 3: 保持最终错误处理**

第二次失败或非超时失败时才调用 `warn("追问建议生成失败：…")`；成功路径继续保存并发布建议。

- [ ] **Step 4: 运行全部测试**

Run: `swift run --package-path InterviewAssistant InterviewAssistantTests`

Expected: 所有测试通过。

- [ ] **Step 5: 提交代码**

```bash
git add InterviewAssistant/Sources/InterviewAssistantCore/Intelligence InterviewAssistant/Tests/InterviewAssistantTests/InterviewIntelligencePipelineTests.swift
git commit -m "fix: retry timed out interview suggestions"
```

### Task 3: 构建并安装

**Files:**
- No source changes expected.

**Interfaces:**
- Consumes: 已通过测试的源码
- Produces: `/Users/ben/Applications/面试助手.app`

- [ ] **Step 1: 构建 Release**

Run: `swift build --package-path InterviewAssistant -c release`

Expected: Build complete。

- [ ] **Step 2: 安装应用**

Run: `zsh InterviewAssistant/Scripts/build-app.sh`

Expected: 新版应用安装到 `/Users/ben/Applications/面试助手.app`。

- [ ] **Step 3: 启动验证**

打开应用，确认能正常启动且签名权限保持有效。
