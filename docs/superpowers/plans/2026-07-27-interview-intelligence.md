# Interview Intelligence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在现有双轨录音基础上，增加本机流式转写、Codex 实时追问建议，以及面试结束后的总评、优势、劣势和风险。

**Architecture:** 系统声音固定为候选人，麦克风固定为面试官。macOS 26 `SpeechAnalyzer` 在本机处理两个声道并发布稳定转写；分析层通过 Provider 协议调用 Codex CLI，Luna 生成实时建议，Sol 生成最终评价。录音、转写和分析相互隔离，后两者失败时原始 CAF 文件仍然完整保存。

**Tech Stack:** Swift 6、SwiftUI、SpeechAnalyzer、Foundation、Codex CLI、Swift Package Manager、现有轻量测试程序

## Global Constraints

- App 仍然只有一个“开始面试/停止面试”主操作。
- 原始录音和语音转写在本机处理，不把音频上传。
- 只有稳定文字可以发送给 Codex。
- Codex 失败不能中断录音或转写。
- 实时建议最多三条，普通提示最短间隔 15 秒。
- 最终评价固定包含总评、优势、劣势、风险。
- 每项判断尽量引用时间戳；证据不足时写“待确认”。
- 当前运行目标为 macOS 26；旧系统显示“不支持本机实时转写”，但仍可录音。
- 测试命令为 `swift run --package-path InterviewAssistant InterviewAssistantTests`。

---

### Task 1: 转写和分析领域模型

**Files:**
- Create: `InterviewAssistant/Sources/InterviewAssistantCore/Intelligence/TranscriptLine.swift`
- Create: `InterviewAssistant/Sources/InterviewAssistantCore/Intelligence/InterviewSuggestion.swift`
- Create: `InterviewAssistant/Sources/InterviewAssistantCore/Intelligence/InterviewEvaluation.swift`
- Create: `InterviewAssistant/Sources/InterviewAssistantCore/Intelligence/AssistantEvent.swift`
- Create: `InterviewAssistant/Tests/InterviewAssistantTests/IntelligenceModelTests.swift`
- Modify: `InterviewAssistant/Tests/InterviewAssistantTests/TestSupport.swift`

**Interfaces:**
- Produces: `TranscriptLine(source:startTime:endTime:text:)`
- Produces: `InterviewSuggestion(question:reason:evidence:)`
- Produces: `InterviewEvaluation(markdown:)`
- Produces: `AssistantEvent`

- [ ] **Step 1: 写失败测试**

```swift
enum IntelligenceModelTests {
    static let all = [
        TestCase(name: "转写行显示说话人和时间") {
            let line = TranscriptLine(
                source: .system,
                startTime: 65,
                endTime: 70,
                text: "我负责推荐项目。"
            )
            try expect(
                line.displayText == "[01:05] 候选人：我负责推荐项目。",
                "系统声音应该显示为候选人"
            )
        },
        TestCase(name: "评价必须包含四个主要部分") {
            let evaluation = InterviewEvaluation(
                markdown: "## 总评\nA\n## 优势\nB\n## 劣势\nC\n## 风险\nD"
            )
            try expect(evaluation.hasRequiredSections, "评价结构不完整")
        }
    ]
}
```

- [ ] **Step 2: 运行测试并确认失败**

Run:

```bash
swift run --package-path InterviewAssistant InterviewAssistantTests
```

Expected: FAIL，原因是领域类型不存在。

- [ ] **Step 3: 实现领域类型**

```swift
public struct TranscriptLine: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let source: AudioSource
    public let startTime: TimeInterval
    public let endTime: TimeInterval
    public let text: String

    public var speakerName: String {
        source == .system ? "候选人" : "面试官"
    }

    public var displayText: String {
        let seconds = max(0, Int(startTime))
        return String(
            format: "[%02d:%02d] %@：%@",
            seconds / 60,
            seconds % 60,
            speakerName,
            text
        )
    }
}

public struct InterviewSuggestion: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let question: String
    public let reason: String
    public let evidence: String
}

public struct InterviewEvaluation: Codable, Equatable, Sendable {
    public let markdown: String

    public var hasRequiredSections: Bool {
        ["## 总评", "## 优势", "## 劣势", "## 风险"]
            .allSatisfy(markdown.contains)
    }
}

public enum AssistantEvent: Sendable {
    case status(String)
    case transcript(TranscriptLine)
    case suggestions([InterviewSuggestion])
    case evaluation(InterviewEvaluation)
    case warning(String)
}
```

- [ ] **Step 4: 运行测试并提交**

```bash
swift run --package-path InterviewAssistant InterviewAssistantTests
git add InterviewAssistant
git commit -m "feat: add interview intelligence models"
```

Expected: 全部测试通过。

---

### Task 2: 本机双路流式转写

**Files:**
- Create: `InterviewAssistant/Sources/InterviewAssistantCore/Intelligence/SpeechRecognitionChannel.swift`
- Create: `InterviewAssistant/Sources/InterviewAssistantCore/Intelligence/LiveTranscriptionService.swift`
- Create: `InterviewAssistant/Sources/InterviewAssistantCore/Intelligence/TranscriptStore.swift`
- Create: `InterviewAssistant/Tests/InterviewAssistantTests/TranscriptStoreTests.swift`

**Interfaces:**
- Consumes: `AudioTapHub.stream`
- Produces: `LiveTranscriptionService.start(directory:eventHandler:)`
- Produces: `LiveTranscriptionService.finish()`
- Produces: `transcript.jsonl` 和 `transcript.md`

- [ ] **Step 1: 写 TranscriptStore 失败测试**

```swift
TestCase(name: "转写按时间保存并生成 Markdown") {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    let store = TranscriptStore(directory: directory)
    try store.append(
        TranscriptLine(
            source: .system,
            startTime: 2,
            endTime: 3,
            text: "候选人回答"
        )
    )
    try store.append(
        TranscriptLine(
            source: .microphone,
            startTime: 1,
            endTime: 2,
            text: "面试官提问"
        )
    )
    try store.finish()
    let markdown = try String(
        contentsOf: directory.appendingPathComponent("transcript.md"),
        encoding: .utf8
    )
    try expect(
        markdown.firstRange(of: "面试官")!.lowerBound
            < markdown.firstRange(of: "候选人")!.lowerBound,
        "应该按时间排序"
    )
}
```

- [ ] **Step 2: 实现 TranscriptStore**

`append` 把每行编码为 JSONL 并保存在内存；`finish` 按 `startTime` 排序后生成
`transcript.md`。所有文件操作放在串行队列中，避免音频回调阻塞。

- [ ] **Step 3: 实现 SpeechRecognitionChannel**

```swift
@available(macOS 26, *)
actor SpeechRecognitionChannel {
    init(source: AudioSource, locale: Locale = Locale(identifier: "zh-CN"))
    func start(
        firstBuffer: AVAudioPCMBuffer,
        handler: @escaping @Sendable (TranscriptLine) -> Void
    ) async throws
    func ingest(_ buffer: AVAudioPCMBuffer)
    func finish() async
}
```

实现要求：

1. 使用 `SpeechTranscriber(locale:preset: .timeIndexedProgressiveTranscription)`；
2. 用 `AssetInventory.assetInstallationRequest` 自动安装中文识别资源；
3. 用 `SpeechAnalyzer.prepareToAnalyze(in: firstBuffer.format)`；
4. 将 `AnalyzerInput(buffer:)` 写入 `AsyncStream`；
5. 只发布去空白、去重复后的稳定结果；
6. 用每个声道的首次结果时间归一化为场次相对时间。

- [ ] **Step 4: 实现 LiveTranscriptionService**

服务启动一个任务消费 `AudioTapHub.stream`，将 `.system` 路由到候选人声道，
将 `.microphone` 路由到面试官声道。收到结果时同时：

```swift
try store.append(line)
eventHandler(.transcript(line))
```

`finish()` 完成两个 analyzer，等待尾部结果并调用 `store.finish()`。

- [ ] **Step 5: 验证并提交**

```bash
swift run --package-path InterviewAssistant InterviewAssistantTests
swift build --package-path InterviewAssistant
git add InterviewAssistant
git commit -m "feat: add local live transcription"
```

Expected: 测试和构建通过。

---

### Task 3: Codex Provider 和提示词

**Files:**
- Create: `InterviewAssistant/Sources/InterviewAssistantCore/Intelligence/InterviewAnalysisProvider.swift`
- Create: `InterviewAssistant/Sources/InterviewAssistantCore/Intelligence/CodexCLIProvider.swift`
- Create: `InterviewAssistant/Sources/InterviewAssistantCore/Intelligence/AnalysisPrompts.swift`
- Create: `InterviewAssistant/Tests/InterviewAssistantTests/AnalysisPromptTests.swift`

**Interfaces:**
- Produces: `generateSuggestions(from:) async throws`
- Produces: `generateEvaluation(from:) async throws`

- [ ] **Step 1: 写提示词失败测试**

```swift
TestCase(name: "评价提示词固定四个部分并要求证据") {
    let prompt = AnalysisPrompts.evaluation(
        transcript: "[01:05] 候选人：我负责项目。"
    )
    for heading in ["## 总评", "## 优势", "## 劣势", "## 风险"] {
        try expect(prompt.contains(heading), "缺少 \(heading)")
    }
    try expect(prompt.contains("时间戳"), "必须要求引用时间戳")
    try expect(prompt.contains("待确认"), "证据不足必须待确认")
}
```

- [ ] **Step 2: 实现 Provider 协议和提示词**

```swift
public protocol InterviewAnalysisProvider: Sendable {
    func generateSuggestions(
        from transcript: [TranscriptLine]
    ) async throws -> [InterviewSuggestion]

    func generateEvaluation(
        from transcript: [TranscriptLine]
    ) async throws -> InterviewEvaluation
}
```

实时建议提示词要求最多三条，每条用三行：

```text
问题：...
原因：...
依据：...
```

最终评价提示词只允许四个一级部分：总评、优势、劣势、风险；每个判断必须附
时间戳，证据不足写“待确认”，不自动做录用或淘汰决定。

- [ ] **Step 3: 实现 CodexCLIProvider**

使用 `/Applications/ChatGPT.app/Contents/Resources/codex`，若不存在则搜索
当前 `PATH`。每次调用：

```text
codex exec
--ephemeral
--skip-git-repo-check
--ignore-rules
--sandbox read-only
--cd <session-directory>
--model <model>
--output-last-message <temporary-output>
<prompt>
```

实时建议使用 `gpt-5.6-luna`，最终评价使用 `gpt-5.6-sol`。实时调用超时 20 秒，
最终评价超时 120 秒。进程失败、超时或输出无法解析时抛出错误，由上层转换成
warning，不影响录音和转写。

- [ ] **Step 4: 验证并提交**

```bash
swift run --package-path InterviewAssistant InterviewAssistantTests
git add InterviewAssistant
git commit -m "feat: add codex interview analysis provider"
```

Expected: 提示词测试通过。

---

### Task 4: 面试智能编排和文件产出

**Files:**
- Create: `InterviewAssistant/Sources/InterviewAssistantCore/Intelligence/InterviewIntelligencePipeline.swift`
- Create: `InterviewAssistant/Sources/InterviewAssistantCore/Session/AssistedInterviewEngine.swift`
- Create: `InterviewAssistant/Tests/InterviewAssistantTests/InterviewIntelligencePipelineTests.swift`

**Interfaces:**
- Consumes: `LiveInterviewRecorder`
- Consumes: `LiveTranscriptionService`
- Consumes: `InterviewAnalysisProvider`
- Produces: `AssistedInterviewEngine.events`
- Produces: `suggestions.jsonl` 和 `evaluation-report.md`

- [ ] **Step 1: 写编排失败测试**

使用假的转写服务和 Provider 验证：

1. 新的稳定候选人回答会触发建议；
2. 15 秒内不会重复触发；
3. `finish()` 一定生成最终评价；
4. Provider 失败只发布 warning。

- [ ] **Step 2: 实现 InterviewIntelligencePipeline**

Pipeline 保存所有稳定转写。候选人新增回答且距离上次分析至少 15 秒时，截取最近
三分钟转写调用建议 Provider。每次建议编码为 JSONL 并发布事件。

`finish()` 等待转写收尾，再调用最终评价，将 Markdown 保存到
`evaluation-report.md` 并发布 `.evaluation`。

- [ ] **Step 3: 实现 AssistedInterviewEngine**

```swift
public final class AssistedInterviewEngine: RecordingEngine, @unchecked Sendable {
    public let events: AsyncStream<AssistantEvent>

    public func start(in directory: URL) async throws {
        try await pipeline.start(in: directory)
        do {
            try await recorder.start(in: directory)
        } catch {
            await pipeline.cancel()
            throw error
        }
    }

    public func stop() async throws {
        try await recorder.stop()
        await pipeline.finish()
    }
}
```

- [ ] **Step 4: 验证并提交**

```bash
swift run --package-path InterviewAssistant InterviewAssistantTests
git add InterviewAssistant
git commit -m "feat: orchestrate live interview intelligence"
```

Expected: 编排测试通过。

---

### Task 5: 一键界面和最终安装

**Files:**
- Modify: `InterviewAssistant/Sources/InterviewAssistantCore/Session/SessionController.swift`
- Modify: `InterviewAssistant/Sources/InterviewAssistantApp/InterviewAssistantApp.swift`
- Modify: `InterviewAssistant/Sources/InterviewAssistantApp/MainView.swift`
- Modify: `InterviewAssistant/README.md`

**Interfaces:**
- Consumes: `AssistedInterviewEngine.events`
- Produces: 实时文字、追问建议和最终评价界面

- [ ] **Step 1: 扩展 SessionController**

增加只读发布状态：

```swift
@Published public private(set) var transcript: [TranscriptLine] = []
@Published public private(set) var suggestions: [InterviewSuggestion] = []
@Published public private(set) var evaluation: InterviewEvaluation?
@Published public private(set) var assistantStatus = "准备转写"
```

Controller 在初始化时消费 `events`，主线程更新上述字段；新场次开始时清空旧内容。

- [ ] **Step 2: 组装真实依赖**

App 使用同一个 `AudioTapHub` 组装：

```swift
let recorder = LiveInterviewRecorder(
    sources: [SystemAudioCapture(), MicrophoneCapture()],
    sink: CAFFileSink(),
    hub: hub
)
let provider = CodexCLIProvider(sessionDirectory: ...)
let pipeline = InterviewIntelligencePipeline(
    hub: hub,
    providerFactory: { directory in
        CodexCLIProvider(sessionDirectory: directory)
    }
)
let engine = AssistedInterviewEngine(
    recorder: recorder,
    pipeline: pipeline
)
```

- [ ] **Step 3: 更新 MainView**

窗口扩大到约 `760 × 680`，但仍只有一个主按钮。内容区包含：

- 顶部：录音状态、系统声音/麦克风状态；
- 左侧：按时间滚动的实时转写；
- 右侧：最多三条当前追问建议；
- 停止后：显示评价 Markdown 的总评、优势、劣势和风险；
- warning 使用黄色小字，不遮挡停止按钮。

- [ ] **Step 4: 完整验证**

```bash
swift run --package-path InterviewAssistant InterviewAssistantTests
swift build --package-path InterviewAssistant -c release
zsh InterviewAssistant/Scripts/build-app.sh
codesign --verify --deep --strict InterviewAssistant/.build/app/面试助手.app
```

Expected: 所有命令退出码为 0。

- [ ] **Step 5: 安装并做真实短录音**

替换 `/Users/ben/Applications/面试助手.app`，运行 60 秒测试，确认：

1. 录音中出现候选人和面试官转写；
2. 候选人回答后出现最多三条追问；
3. 停止后生成 `transcript.md`、`suggestions.jsonl` 和
   `evaluation-report.md`；
4. 原始 `system.caf` 和 `microphone.caf` 仍能打开。

- [ ] **Step 6: 提交**

```bash
git add InterviewAssistant
git commit -m "feat: deliver live transcription and interview evaluation"
```
