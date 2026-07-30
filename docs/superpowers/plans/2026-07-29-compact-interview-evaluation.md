# 精简面试评价 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 最终面试评价不再显示逐字稿时间戳，并将总评和三个列表部分收紧到更易读的长度。

**Architecture:** `AnalysisPrompts` 负责要求模型生成精简内容；新增 `CompactInterviewEvaluation` 负责确定性清理时间戳、空括号和多余条目。`CodexCLIProvider` 只接受清理后仍具有四个完整章节的结果，并把同一结果交给界面和文件保存流程。

**Tech Stack:** Swift 6、Foundation 正则表达式、自定义轻量测试框架。

## Global Constraints

- 保留“总评、优势、劣势、风险”四个部分。
- 总评为 100 至 150 个中文字符，最多三句话。
- 优势、劣势、风险各最多三条，每条 30 至 60 个中文字符。
- 不输出或保留任何单个时间戳和时间范围。
- 程序不截断单条中文内容。

---

### Task 1: 用测试定义精简规则

**Files:**
- Modify: `InterviewAssistant/Tests/InterviewAssistantTests/AnalysisPromptTests.swift`
- Modify: `InterviewAssistant/Tests/InterviewAssistantTests/IntelligenceModelTests.swift`

**Interfaces:**
- Consumes: `AnalysisPrompts.evaluation(transcript:resume:)`
- Produces: `CompactInterviewEvaluation.normalize(_:) -> InterviewEvaluation?` 的行为要求

- [ ] **Step 1: 修改提示词测试**

断言提示词明确包含“不得输出任何逐字稿时间戳”“100 至 150 个字符”“最多 3 条”和“30 至 60 个字符”。

- [ ] **Step 2: 增加清理测试**

构造带有 `[02:18]-[04:35]`、`[12:13]`、空括号和四条优势的评价，断言输出不含时间戳、空括号，且优势只保留前三条。

- [ ] **Step 3: 运行测试确认失败**

Run: `swift run --package-path InterviewAssistant InterviewAssistantTests`

Expected: 新增测试因 `CompactInterviewEvaluation` 不存在或现有提示词仍要求时间戳而失败。

### Task 2: 实现生成约束和程序清理

**Files:**
- Create: `InterviewAssistant/Sources/InterviewAssistantCore/Intelligence/CompactInterviewEvaluation.swift`
- Modify: `InterviewAssistant/Sources/InterviewAssistantCore/Intelligence/AnalysisPrompts.swift`
- Modify: `InterviewAssistant/Sources/InterviewAssistantCore/Intelligence/CodexCLIProvider.swift`

**Interfaces:**
- Produces: `public static func normalize(_ markdown: String) -> InterviewEvaluation?`
- Consumes: `CompactResumeEvaluation.section(_:in:)` 等价的章节解析规则

- [ ] **Step 1: 更新最终评价提示词**

删除“尽量引用逐字稿时间戳”，改成禁止输出时间戳，并写明总评、条目数量和条目长度。

- [ ] **Step 2: 实现时间戳清理**

先删除 `[mm:ss]-[mm:ss]` 范围，再删除单个 `[mm:ss]`；随后清理空括号、重复顿号、重复空格和行尾多余标点。

- [ ] **Step 3: 实现章节精简**

总评合并为一个段落；优势、劣势、风险解析非空行、统一为 `- ` 前缀，并只保留前三条。

- [ ] **Step 4: 接入 Provider**

`validatedEvaluation(_:)` 使用 `CompactInterviewEvaluation.normalize`，清理失败时继续返回“缺少评价章节”错误。

- [ ] **Step 5: 运行全部测试**

Run: `swift run --package-path InterviewAssistant InterviewAssistantTests`

Expected: 全部测试通过。

- [ ] **Step 6: 提交代码**

```bash
git add InterviewAssistant/Sources/InterviewAssistantCore/Intelligence InterviewAssistant/Tests/InterviewAssistantTests
git commit -m "fix: simplify final interview evaluations"
```

### Task 3: 构建并安装新版

**Files:**
- No source changes expected.

**Interfaces:**
- Consumes: 已通过测试的 Swift 源码
- Produces: `/Users/ben/Applications/面试助手.app`

- [ ] **Step 1: 构建 Release 应用**

Run: `zsh InterviewAssistant/Scripts/build-app.sh`

Expected: 构建完成并通过代码签名验证。

- [ ] **Step 2: 替换并打开应用**

退出旧进程，用 `ditto` 安装新包，再打开 `/Users/ben/Applications/面试助手.app`。

- [ ] **Step 3: 验证安装**

检查代码签名、运行进程和完整测试结果。
