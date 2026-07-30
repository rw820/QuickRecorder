# Compact Resume Evaluation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 精简简历初评、补充五个建议问题，并支持一键刷新。

**Architecture:** 模型提示词负责生成短内容，本地格式化器负责兜底限制四个评价部分的长度和问题数量。刷新通过现有简历服务重新评价已保存文本，控制器负责状态，SwiftUI 负责按钮和第五块内容展示。

**Tech Stack:** Swift 6、SwiftUI、Swift Testing、Codex CLI

## Global Constraints

- 总评、优势、劣势、风险分别不超过 50 个字符，可以包含一到三句。
- 建议问题固定为 5 个。
- 只精简简历初评，不改变面试结束后的最终评价。
- 刷新失败保留旧评价。

---

### Task 1: 短评价格式约束

**Files:**
- Create: `InterviewAssistant/Sources/InterviewAssistantCore/Intelligence/CompactResumeEvaluation.swift`
- Modify: `InterviewAssistant/Sources/InterviewAssistantCore/Intelligence/AnalysisPrompts.swift`
- Modify: `InterviewAssistant/Sources/InterviewAssistantCore/Intelligence/CodexCLIProvider.swift`
- Test: `InterviewAssistant/Tests/InterviewAssistantTests/AnalysisPromptTests.swift`

**Interfaces:**
- Consumes: Codex 返回的 Markdown 文本。
- Produces: `CompactResumeEvaluation.normalize(_:) -> InterviewEvaluation?`。

- [ ] **Step 1: 写失败测试**

验证提示词包含“每部分不超过50字”和“固定5个问题”；验证超长模型结果会被规范为四个短段和五个问题。

- [ ] **Step 2: 运行测试确认失败**

Run: `swift test --package-path InterviewAssistant`
Expected: 新增约束测试失败。

- [ ] **Step 3: 实现最小格式化逻辑**

解析五个 Markdown 标题；四个评价段清理列表符号、压缩空白并限制到 50 个字符；问题清理编号、取前五个并重新编号。Codex provider 返回规范化后的结果。

- [ ] **Step 4: 运行测试确认通过**

Run: `swift test --package-path InterviewAssistant`
Expected: 所有测试通过。

- [ ] **Step 5: 提交**

```bash
git add InterviewAssistant
git commit -m "feat: compact resume evaluation output"
```

### Task 2: 刷新服务和控制器

**Files:**
- Modify: `InterviewAssistant/Sources/InterviewAssistantCore/Resume/ResumeImportService.swift`
- Modify: `InterviewAssistant/Sources/InterviewAssistantCore/Session/SessionController.swift`
- Modify: `InterviewAssistant/Tests/InterviewAssistantTests/ResumeImportServiceTests.swift`
- Modify: `InterviewAssistant/Tests/InterviewAssistantTests/SessionControllerTests.swift`

**Interfaces:**
- Consumes: 当前保存的 `CandidateResume`。
- Produces: `ResumeImportServicing.refreshEvaluation() async throws -> InterviewEvaluation` 和 `SessionController.refreshResumeEvaluation()`。

- [ ] **Step 1: 写失败测试**

服务测试验证刷新使用当前简历并覆盖评价文件；控制器测试验证成功时更新界面、失败时保留旧值。

- [ ] **Step 2: 运行测试确认失败**

Run: `swift test --package-path InterviewAssistant`
Expected: 刷新接口不存在，测试失败。

- [ ] **Step 3: 实现刷新**

服务从存储恢复简历，调用 provider 并保存新评价；控制器增加刷新中状态和公开刷新方法，使用 `defer` 恢复按钮状态。

- [ ] **Step 4: 运行测试确认通过**

Run: `swift test --package-path InterviewAssistant`
Expected: 所有测试通过。

- [ ] **Step 5: 提交**

```bash
git add InterviewAssistant
git commit -m "feat: refresh resume evaluation"
```

### Task 3: 界面、安装和验收

**Files:**
- Modify: `InterviewAssistant/Sources/InterviewAssistantApp/MainView.swift`

**Interfaces:**
- Consumes: `SessionController.isRefreshingResumeEvaluation` 和 `refreshResumeEvaluation()`。
- Produces: “建议问题”卡片和“刷新评价和问题”按钮。

- [ ] **Step 1: 修改界面**

在简历初评标题旁显示刷新按钮；刷新时显示进度并禁用按钮；增加建议问题卡片。

- [ ] **Step 2: 完整验证**

Run: `swift test --package-path InterviewAssistant`
Expected: 所有测试通过。

Run: `./InterviewAssistant/scripts/install-app.sh`
Expected: `/Users/ben/Applications/面试助手.app` 更新成功。

- [ ] **Step 3: 启动并人工检查**

打开应用，确认已有简历显示五块内容，按钮可刷新，四个评价部分均不超过 50 字。

- [ ] **Step 4: 提交**

```bash
git add InterviewAssistant
git commit -m "feat: show resume questions and refresh control"
```
