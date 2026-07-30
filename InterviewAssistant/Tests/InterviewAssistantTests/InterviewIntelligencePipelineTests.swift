import Foundation
import InterviewAssistantCore

private final class FakeAnalysisProvider:
    InterviewAnalysisProvider,
    @unchecked Sendable
{
    private let lock = NSLock()
    private let shouldFail: Bool
    private var suggestionCallCount = 0
    private var evaluationCallCount = 0
    private var suggestionResume: String?
    private var evaluationResume: String?

    init(shouldFail: Bool = false) {
        self.shouldFail = shouldFail
    }

    func generateResumeEvaluation(
        from resumeText: String
    ) async throws -> InterviewEvaluation {
        try recordEvaluationCall()
        return InterviewEvaluation(
            markdown: "## 总评\nA\n## 优势\nB\n## 劣势\nC\n## 风险\nD"
        )
    }

    func generateSuggestions(
        from transcript: [TranscriptLine],
        resumeText: String?
    ) async throws -> [InterviewSuggestion] {
        try recordSuggestionCall(resumeText: resumeText)
        return [
            InterviewSuggestion(
                question: "你个人负责了哪一部分？",
                reason: "区分个人贡献",
                evidence: transcript.last?.displayText ?? ""
            )
        ]
    }

    func generateEvaluation(
        from transcript: [TranscriptLine],
        resumeText: String?
    ) async throws -> InterviewEvaluation {
        try recordEvaluationCall(resumeText: resumeText)
        return InterviewEvaluation(
            markdown: """
            ## 总评
            表现稳定。
            ## 优势
            有业务意识。
            ## 劣势
            技术细节不足。
            ## 风险
            个人贡献待确认。
            """
        )
    }

    func counts() -> (suggestions: Int, evaluations: Int) {
        lock.withLock {
            (suggestionCallCount, evaluationCallCount)
        }
    }

    func resumeSnapshot() -> (
        suggestion: String?,
        evaluation: String?
    ) {
        lock.withLock { (suggestionResume, evaluationResume) }
    }

    private func recordSuggestionCall(
        resumeText: String? = nil
    ) throws {
        try lock.withLock {
            suggestionCallCount += 1
            suggestionResume = resumeText
            if shouldFail { throw TestFailure(description: "模拟失败") }
        }
    }

    private func recordEvaluationCall(
        resumeText: String? = nil
    ) throws {
        try lock.withLock {
            evaluationCallCount += 1
            evaluationResume = resumeText
            if shouldFail { throw TestFailure(description: "模拟失败") }
        }
    }
}

private final class RetryingSuggestionProvider:
    InterviewAnalysisProvider,
    @unchecked Sendable
{
    enum FirstFailure {
        case timeout
        case other
    }

    private let lock = NSLock()
    private let firstFailure: FirstFailure
    private var suggestionCallCount = 0

    init(firstFailure: FirstFailure) {
        self.firstFailure = firstFailure
    }

    func generateResumeEvaluation(
        from resumeText: String
    ) async throws -> InterviewEvaluation {
        successfulEvaluation()
    }

    func generateSuggestions(
        from transcript: [TranscriptLine],
        resumeText: String?
    ) async throws -> [InterviewSuggestion] {
        let call = lock.withLock {
            suggestionCallCount += 1
            return suggestionCallCount
        }
        if call == 1 {
            switch firstFailure {
            case .timeout:
                throw CodexCLIProviderError.timedOut
            case .other:
                throw TestFailure(description: "模拟非超时失败")
            }
        }
        return [
            InterviewSuggestion(
                question: "请说明你个人负责的关键决策。",
                reason: "确认个人贡献",
                evidence: transcript.last?.displayText ?? ""
            )
        ]
    }

    func generateEvaluation(
        from transcript: [TranscriptLine],
        resumeText: String?
    ) async throws -> InterviewEvaluation {
        successfulEvaluation()
    }

    func suggestionCount() -> Int {
        lock.withLock { suggestionCallCount }
    }

    private func successfulEvaluation() -> InterviewEvaluation {
        InterviewEvaluation(
            markdown: """
            ## 总评
            表现稳定。
            ## 优势
            有业务意识。
            ## 劣势
            技术细节不足。
            ## 风险
            个人贡献待确认。
            """
        )
    }
}

enum InterviewIntelligencePipelineTests {
    static let all = [
        TestCase(name: "追问首次超时会自动重试一次") {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            defer { try? FileManager.default.removeItem(at: directory) }
            let provider = RetryingSuggestionProvider(firstFailure: .timeout)
            let pipeline = InterviewIntelligencePipeline(
                hub: AudioTapHub(),
                providerFactory: { _ in provider }
            )

            try await pipeline.start(in: directory)
            await pipeline.accept(
                TranscriptLine(
                    source: .system,
                    startTime: 1,
                    endTime: 4,
                    text: "我负责这个项目的数据产品设计和落地。"
                )
            )
            await pipeline.finish()

            try expect(
                provider.suggestionCount() == 2,
                "首次超时后应自动重试一次"
            )
            let warning = await pipeline.latestWarning()
            try expect(
                warning == nil,
                "重试成功后不应显示失败警告"
            )
        },
        TestCase(name: "追问非超时错误不会重试") {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            defer { try? FileManager.default.removeItem(at: directory) }
            let provider = RetryingSuggestionProvider(firstFailure: .other)
            let pipeline = InterviewIntelligencePipeline(
                hub: AudioTapHub(),
                providerFactory: { _ in provider }
            )

            try await pipeline.start(in: directory)
            await pipeline.accept(
                TranscriptLine(
                    source: .system,
                    startTime: 1,
                    endTime: 4,
                    text: "我负责这个项目的数据产品设计和落地。"
                )
            )
            await pipeline.finish()

            try expect(
                provider.suggestionCount() == 1,
                "非超时错误不应重试"
            )
            let warning = await pipeline.latestWarning()
            try expect(
                warning?.contains("追问建议生成失败") == true,
                "非超时错误应显示失败警告"
            )
        },
        TestCase(name: "候选人回答触发建议且十五秒内不重复") {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            defer { try? FileManager.default.removeItem(at: directory) }
            let provider = FakeAnalysisProvider()
            let pipeline = InterviewIntelligencePipeline(
                hub: AudioTapHub(),
                providerFactory: { _ in provider }
            )

            try await pipeline.start(in: directory)
            await pipeline.accept(
                TranscriptLine(
                    source: .system,
                    startTime: 1,
                    endTime: 4,
                    text: "我负责这个项目的数据产品设计和落地。"
                )
            )
            await pipeline.accept(
                TranscriptLine(
                    source: .system,
                    startTime: 8,
                    endTime: 12,
                    text: "我们最后把转化率提升了十个百分点。"
                )
            )
            await pipeline.finish()

            let counts = provider.counts()
            try expect(counts.suggestions == 1, "十五秒内只能请求一次建议")
            try expect(counts.evaluations == 1, "停止后必须请求最终评价")
            try expect(
                FileManager.default.fileExists(
                    atPath: directory
                        .appendingPathComponent("suggestions.jsonl").path
                ),
                "应保存建议 JSONL"
            )
            try expect(
                FileManager.default.fileExists(
                    atPath: directory
                        .appendingPathComponent("evaluation-report.md").path
                ),
                "应保存最终评价"
            )
        },
        TestCase(name: "分析失败只产生警告并保留评价文件") {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            defer { try? FileManager.default.removeItem(at: directory) }
            let provider = FakeAnalysisProvider(shouldFail: true)
            let pipeline = InterviewIntelligencePipeline(
                hub: AudioTapHub(),
                providerFactory: { _ in provider }
            )

            try await pipeline.start(in: directory)
            await pipeline.accept(
                TranscriptLine(
                    source: .system,
                    startTime: 1,
                    endTime: 4,
                    text: "我负责这个项目的数据产品设计和落地。"
                )
            )
            await pipeline.finish()

            let warning = await pipeline.latestWarning()
            try expect(
                warning != nil,
                "Provider 失败应记录 warning"
            )
            try expect(
                FileManager.default.fileExists(
                    atPath: directory
                        .appendingPathComponent("evaluation-report.md").path
                ),
                "失败时也应生成可读的评价文件"
            )
        },
        TestCase(name: "实时建议和最终评价会使用当前简历") {
            let base = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            let session = base.appendingPathComponent(
                "Session",
                isDirectory: true
            )
            let source = base.appendingPathComponent("candidate.txt")
            let resumeStore = CurrentResumeStore(
                root: base.appendingPathComponent(
                    "CurrentCandidate",
                    isDirectory: true
                )
            )
            defer { try? FileManager.default.removeItem(at: base) }
            try FileManager.default.createDirectory(
                at: base,
                withIntermediateDirectories: true
            )
            try "候选人简历原文件".write(
                to: source,
                atomically: true,
                encoding: .utf8
            )
            _ = try resumeStore.save(
                sourceURL: source,
                text: "候选人拥有八年数据产品经验。"
            )
            try resumeStore.saveEvaluation(
                InterviewEvaluation(
                    markdown:
                        "## 总评\nA\n## 优势\nB\n## 劣势\nC\n## 风险\nD"
                )
            )

            let provider = FakeAnalysisProvider()
            let pipeline = InterviewIntelligencePipeline(
                hub: AudioTapHub(),
                providerFactory: { _ in provider },
                resumeStore: resumeStore
            )
            try await pipeline.start(in: session)
            await pipeline.accept(
                TranscriptLine(
                    source: .system,
                    startTime: 1,
                    endTime: 4,
                    text: "我负责这个项目的数据产品设计和落地。"
                )
            )
            await pipeline.finish()

            let resumeSnapshot = provider.resumeSnapshot()
            try expect(
                resumeSnapshot.suggestion?.contains("八年") == true,
                "实时建议应收到简历"
            )
            try expect(
                resumeSnapshot.evaluation?.contains("八年") == true,
                "最终评价应收到简历"
            )
            try expect(
                FileManager.default.fileExists(
                    atPath: session.appendingPathComponent(
                        "resume.txt"
                    ).path
                ),
                "面试场次应复制简历文字"
            )
        }
    ]
}
