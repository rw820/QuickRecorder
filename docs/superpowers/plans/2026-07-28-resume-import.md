# Resume Import Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 支持导入 PDF、Word、TXT 和图片简历，自动生成简历初评，并让实时建议和最终评价结合简历内容。

**Architecture:** `ResumeTextExtractor` 在本机解析文件，`CurrentResumeStore` 保存当前候选人，`ResumeImportService` 负责自动初评。现有分析 Provider 增加可选简历上下文，Pipeline 在每场面试开始时读取并复制当前简历产物。

**Tech Stack:** Swift 6、SwiftUI、PDFKit、Vision、ImageIO、AppKit、UniformTypeIdentifiers、Codex CLI

## Global Constraints

- 原始简历不上传，只把本机提取后的文字交给 Codex。
- 保持“开始面试/停止并生成评价”为唯一主要操作。
- 支持 PDF、DOC、DOCX、TXT、PNG、JPG 和 JPEG。
- 扫描 PDF 和图片使用 macOS 本机 OCR，识别简体中文和英文。
- 简历解析或分析失败不得影响录音。
- 初评和最终评价固定包含总评、优势、劣势、风险。
- 测试命令为 `swift run --package-path InterviewAssistant InterviewAssistantTests`。

---

### Task 1: 简历领域模型和本机存储

**Files:**
- Create: `InterviewAssistant/Sources/InterviewAssistantCore/Resume/ResumeDocument.swift`
- Create: `InterviewAssistant/Sources/InterviewAssistantCore/Resume/CurrentResumeStore.swift`
- Create: `InterviewAssistant/Tests/InterviewAssistantTests/CurrentResumeStoreTests.swift`
- Modify: `InterviewAssistant/Tests/InterviewAssistantTests/TestSupport.swift`

**Interfaces:**
- Produces: `ResumeDocument(originalFileName:text:importedAt:localFileURL:)`
- Produces: `CurrentResumeStore.save(sourceURL:text:)`
- Produces: `CurrentResumeStore.load()`
- Produces: `CurrentResumeStore.saveEvaluation(_:)`
- Produces: `CurrentResumeStore.clear()`
- Produces: `CurrentResumeStore.copyArtifacts(to:)`

- [ ] **Step 1: Write the failing storage test**

测试先保存一个 TXT 简历，再恢复文件名和文字，保存初评并复制到场次目录，最后清除。

- [ ] **Step 2: Run the test to verify failure**

Run: `swift run --package-path InterviewAssistant InterviewAssistantTests`

Expected: FAIL because `ResumeDocument` and `CurrentResumeStore` do not exist.

- [ ] **Step 3: Implement atomic local storage**

`save` 先在同级 staging 目录写入 `original.<ext>`、`resume.txt` 和
`resume-metadata.json`，再替换 `CurrentCandidate`。`saveEvaluation` 写入
`resume-evaluation.md`。`copyArtifacts` 把文字和已有初评复制到面试场次目录。

- [ ] **Step 4: Run tests and commit**

```bash
swift run --package-path InterviewAssistant InterviewAssistantTests
git add InterviewAssistant
git commit -m "feat: persist current candidate resume"
```

---

### Task 2: PDF、Word、TXT 和图片文字提取

**Files:**
- Create: `InterviewAssistant/Sources/InterviewAssistantCore/Resume/ResumeTextExtractor.swift`
- Create: `InterviewAssistant/Sources/InterviewAssistantCore/Resume/ResumeExtractionError.swift`
- Create: `InterviewAssistant/Tests/InterviewAssistantTests/ResumeTextExtractorTests.swift`
- Modify: `InterviewAssistant/Tests/InterviewAssistantTests/TestSupport.swift`

**Interfaces:**
- Produces: `ResumeTextExtractor.extractText(from:) async throws -> String`
- Consumes: local file URL

- [ ] **Step 1: Write failing tests**

覆盖 TXT、包含可复制文字的 PDF、不支持扩展名和空文本。DOCX 测试使用系统
`textutil` 从测试文本生成临时文件。图片 OCR 使用测试代码绘制中英文文字图片。

- [ ] **Step 2: Run tests to verify failure**

Run: `swift run --package-path InterviewAssistant InterviewAssistantTests`

Expected: FAIL because `ResumeTextExtractor` does not exist.

- [ ] **Step 3: Implement extractors**

按扩展名路由：

```swift
switch fileExtension {
case "pdf": extractPDF(url)
case "doc", "docx": extractAttributedDocument(url)
case "txt": extractPlainText(url)
case "png", "jpg", "jpeg": recognizeImage(url)
default: throw ResumeExtractionError.unsupportedFormat
}
```

PDFKit 文字少于 20 字时逐页转为 `CGImage` 并调用 Vision。Vision 使用
`.accurate`、`recognitionLanguages = ["zh-Hans", "en-US"]`，按文字框从上到下合并。

- [ ] **Step 4: Run tests and commit**

```bash
swift run --package-path InterviewAssistant InterviewAssistantTests
git add InterviewAssistant
git commit -m "feat: extract resume text locally"
```

---

### Task 3: 简历初评和联合分析提示词

**Files:**
- Create: `InterviewAssistant/Sources/InterviewAssistantCore/Resume/ResumeImportService.swift`
- Modify: `InterviewAssistant/Sources/InterviewAssistantCore/Intelligence/InterviewAnalysisProvider.swift`
- Modify: `InterviewAssistant/Sources/InterviewAssistantCore/Intelligence/AnalysisPrompts.swift`
- Modify: `InterviewAssistant/Sources/InterviewAssistantCore/Intelligence/CodexCLIProvider.swift`
- Modify: `InterviewAssistant/Tests/InterviewAssistantTests/AnalysisPromptTests.swift`
- Modify: `InterviewAssistant/Tests/InterviewAssistantTests/InterviewIntelligencePipelineTests.swift`

**Interfaces:**
- Produces: `ResumeImportService.importResume(from:) async throws -> ResumeImportResult`
- Produces: `ResumeImportService.restore()`
- Produces: `ResumeImportService.clear()`
- Produces: `generateResumeEvaluation(from:)`
- Changes: suggestion and final evaluation methods accept `resumeText: String?`

- [ ] **Step 1: Write failing prompt and service tests**

断言初评提示词包含四个固定标题、“待面试验证”和“不做录用决定”；联合评价提示词
同时包含简历与逐字稿，并要求冲突进入风险。Service 测试使用假的 Extractor 和
Provider 验证导入后自动保存初评。

- [ ] **Step 2: Run tests to verify failure**

Run: `swift run --package-path InterviewAssistant InterviewAssistantTests`

Expected: FAIL on missing resume APIs.

- [ ] **Step 3: Implement Provider and service**

`ResumeImportService` 先提取并保存，即使 Codex 失败也返回成功导入的
`ResumeDocument` 和 warning。`CodexCLIProvider` 使用 Sol 生成初评；实时 Luna
提示词把简历放在独立的“简历声明”区；最终 Sol 提示词明确区分声明和面试证据。

- [ ] **Step 4: Run tests and commit**

```bash
swift run --package-path InterviewAssistant InterviewAssistantTests
git add InterviewAssistant
git commit -m "feat: add resume-aware interview analysis"
```

---

### Task 4: Pipeline 使用当前简历

**Files:**
- Modify: `InterviewAssistant/Sources/InterviewAssistantCore/Intelligence/InterviewIntelligencePipeline.swift`
- Modify: `InterviewAssistant/Sources/InterviewAssistantApp/InterviewAssistantApp.swift`
- Modify: `InterviewAssistant/Tests/InterviewAssistantTests/InterviewIntelligencePipelineTests.swift`

**Interfaces:**
- Consumes: `CurrentResumeStore.load()`
- Consumes: `CurrentResumeStore.copyArtifacts(to:)`
- Produces: resume-aware suggestions and final evaluation

- [ ] **Step 1: Extend pipeline tests**

保存一份当前简历，启动 Pipeline，注入假的 Provider，断言建议和最终评价收到相同
的简历文字，并断言场次目录包含 `resume.txt` 和 `resume-evaluation.md`。

- [ ] **Step 2: Run tests to verify failure**

Run: `swift run --package-path InterviewAssistant InterviewAssistantTests`

Expected: FAIL because Pipeline does not load resume context.

- [ ] **Step 3: Implement session integration**

Pipeline `start(in:)` 加载当前简历并复制产物；`generateSuggestions` 和 `finish`
调用 Provider 时传入 `resume?.text`。恢复或复制失败只发布 warning。

- [ ] **Step 4: Run tests and commit**

```bash
swift run --package-path InterviewAssistant InterviewAssistantTests
git add InterviewAssistant
git commit -m "feat: use resume context during interviews"
```

---

### Task 5: 导入界面、恢复和最终安装

**Files:**
- Modify: `InterviewAssistant/Sources/InterviewAssistantCore/Session/SessionController.swift`
- Modify: `InterviewAssistant/Sources/InterviewAssistantApp/MainView.swift`
- Modify: `InterviewAssistant/Sources/InterviewAssistantApp/InterviewAssistantApp.swift`
- Modify: `InterviewAssistant/Tests/InterviewAssistantTests/SessionControllerTests.swift`
- Modify: `InterviewAssistant/README.md`

**Interfaces:**
- Produces: `SessionController.importResume(from:)`
- Produces: `SessionController.clearResume()`
- Produces: published `resume`, `resumeStatus`, `evaluationTitle`

- [ ] **Step 1: Write failing controller tests**

假的 ResumeImportService 返回简历和初评，断言 Controller 更新当前文件、状态和
评价；清除后恢复空状态。

- [ ] **Step 2: Run tests to verify failure**

Run: `swift run --package-path InterviewAssistant InterviewAssistantTests`

Expected: FAIL because Controller has no resume state.

- [ ] **Step 3: Implement one-click UI**

顶部加入“导入简历”次要按钮和文件名卡片，使用 `fileImporter` 接受规定格式，
窗口主体支持文件 URL 拖入。处理中禁用重复导入；导入后自动显示“简历初评”。
开始面试时保留简历但清除初评，结束后显示“本次面试评价”。

- [ ] **Step 4: Verify, package, install and commit**

```bash
swift run --package-path InterviewAssistant InterviewAssistantTests
zsh InterviewAssistant/Scripts/build-app.sh
codesign --verify --deep --strict InterviewAssistant/.build/app/面试助手.app
ditto InterviewAssistant/.build/app/面试助手.app /Users/ben/Applications/面试助手.app
git add InterviewAssistant
git commit -m "feat: deliver resume import and evaluation"
```

Expected: tests pass, release app is signed, and the installed app opens with the resume import entry.
