import Foundation
import InterviewAssistantCore

private actor RecordingEngineSpy: RecordingEngine {
    private var starts: [URL] = []
    private var stopCount = 0

    func start(in directory: URL) async throws {
        starts.append(directory)
    }

    func stop() async throws {
        stopCount += 1
    }

    func snapshot() -> (starts: Int, stops: Int) {
        (starts.count, stopCount)
    }
}

private actor ResumeImportServiceSpy: ResumeImportServicing {
    private let result: ResumeImportResult
    private let refreshedEvaluation: InterviewEvaluation
    private var cleared = false
    private var refreshCount = 0

    init(
        result: ResumeImportResult,
        refreshedEvaluation: InterviewEvaluation? = nil
    ) {
        self.result = result
        self.refreshedEvaluation =
            refreshedEvaluation ?? result.evaluation
            ?? InterviewEvaluation(markdown: "")
    }

    func importResume(from url: URL) async throws -> ResumeImportResult {
        result
    }

    func restore() async throws -> ResumeImportResult? {
        nil
    }

    func refreshEvaluation() async throws -> InterviewEvaluation {
        refreshCount += 1
        return refreshedEvaluation
    }

    func clear() async throws {
        cleared = true
    }

    func wasCleared() -> Bool {
        cleared
    }

    func refreshes() -> Int {
        refreshCount
    }
}

enum SessionControllerTests {
    static let all = [
        TestCase(name: "开始和停止会驱动录音器与界面状态") {
            let root = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
            let engine = RecordingEngineSpy()
            let controller = SessionController(
                engine: engine,
                store: SessionDirectoryStore(root: root)
            )

            await controller.start()
            guard case .recording = controller.state else {
                throw TestFailure(description: "开始后应该处于录音状态")
            }

            await controller.stop()
            try expect(controller.state == .idle, "停止后应该回到准备状态")
            let counts = await engine.snapshot()
            try expect(counts.starts == 1, "录音器应该启动一次")
            try expect(counts.stops == 1, "录音器应该停止一次")
        },
        TestCase(name: "智能事件会更新转写建议和评价") {
            let pair = AsyncStream.makeStream(of: AssistantEvent.self)
            let controller = SessionController(
                engine: RecordingEngineSpy(),
                events: pair.stream
            )
            let line = TranscriptLine(
                source: .system,
                startTime: 1,
                endTime: 2,
                text: "这是候选人的回答。"
            )
            let suggestion = InterviewSuggestion(
                question: "你的个人贡献是什么？",
                reason: "需要区分团队贡献",
                evidence: "[00:01]"
            )
            let evaluation = InterviewEvaluation(
                markdown: "## 总评\nA\n## 优势\nB\n## 劣势\nC\n## 风险\nD"
            )

            pair.continuation.yield(.transcript(line))
            pair.continuation.yield(.suggestions([suggestion]))
            pair.continuation.yield(.evaluation(evaluation))
            try? await Task.sleep(for: .milliseconds(20))

            try expect(controller.transcript == [line], "应显示实时转写")
            try expect(
                controller.suggestions == [suggestion],
                "应显示追问建议"
            )
            try expect(
                controller.evaluation == evaluation,
                "应显示最终评价"
            )
        },
        TestCase(name: "正式转写会替换对应音源的临时文字") {
            let pair = AsyncStream.makeStream(of: AssistantEvent.self)
            let controller = SessionController(
                engine: RecordingEngineSpy(),
                events: pair.stream
            )
            let line = TranscriptLine(
                source: .system,
                startTime: 1,
                endTime: 2,
                text: "这是最终结果。"
            )

            pair.continuation.yield(
                .partialTranscript(
                    source: .system,
                    text: "这是临时结果"
                )
            )
            try? await Task.sleep(for: .milliseconds(20))
            try expect(
                controller.partialTranscripts[.system]
                    == "这是临时结果",
                "应显示候选人临时转写"
            )

            pair.continuation.yield(.transcript(line))
            try? await Task.sleep(for: .milliseconds(20))
            try expect(
                controller.partialTranscripts[.system] == nil,
                "正式转写到达后应清除临时文字"
            )
        },
        TestCase(name: "导入简历会自动显示初评并可清除") {
            let evaluation = InterviewEvaluation(
                markdown: "## 总评\nA\n## 优势\nB\n## 劣势\nC\n## 风险\nD"
            )
            let document = ResumeDocument(
                originalFileName: "候选人.pdf",
                text: "八年数据产品经验",
                localFileURL: URL(fileURLWithPath: "/tmp/candidate.pdf")
            )
            let service = ResumeImportServiceSpy(
                result: ResumeImportResult(
                    document: document,
                    evaluation: evaluation,
                    warning: nil
                )
            )
            let controller = SessionController(
                engine: RecordingEngineSpy(),
                resumeService: service
            )

            await controller.importResume(
                from: URL(fileURLWithPath: "/tmp/source.pdf")
            )

            try expect(controller.resume == document, "应显示当前简历")
            try expect(controller.evaluation == evaluation, "应显示简历初评")
            try expect(
                controller.evaluationTitle == "简历初评",
                "评价标题错误"
            )

            await controller.clearResume()
            try expect(controller.resume == nil, "应清除当前简历")
            let cleared = await service.wasCleared()
            try expect(cleared, "应调用本机清除")
        },
        TestCase(name: "刷新会更新当前简历初评") {
            let oldEvaluation = InterviewEvaluation(
                markdown: "## 总评\n旧\n## 优势\n旧\n## 劣势\n旧\n## 风险\n旧"
            )
            let newEvaluation = InterviewEvaluation(
                markdown: "## 总评\n新\n## 优势\n新\n## 劣势\n新\n## 风险\n新"
            )
            let document = ResumeDocument(
                originalFileName: "候选人.pdf",
                text: "简历",
                localFileURL: URL(fileURLWithPath: "/tmp/candidate.pdf")
            )
            let service = ResumeImportServiceSpy(
                result: ResumeImportResult(
                    document: document,
                    evaluation: oldEvaluation,
                    warning: nil
                ),
                refreshedEvaluation: newEvaluation
            )
            let controller = SessionController(
                engine: RecordingEngineSpy(),
                resumeService: service
            )
            await controller.importResume(
                from: URL(fileURLWithPath: "/tmp/source.pdf")
            )

            await controller.refreshResumeEvaluation()

            try expect(
                controller.evaluation == newEvaluation,
                "刷新后应显示新评价"
            )
            try expect(
                !controller.isRefreshingResumeEvaluation,
                "刷新结束后按钮应恢复"
            )
            let refreshes = await service.refreshes()
            try expect(refreshes == 1, "应刷新一次")
        }
    ]
}
