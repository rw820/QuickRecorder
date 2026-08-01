import Foundation
import InterviewAssistantCore

private actor HistoricalProviderStub: InterviewAnalysisProvider {
    enum StubError: Error {
        case failed
    }

    private let result: InterviewEvaluation
    private let shouldFail: Bool
    private(set) var capturedTranscript: [TranscriptLine] = []
    private(set) var capturedResume: String?
    private(set) var capturedRequirement: String?

    init(
        result: InterviewEvaluation,
        shouldFail: Bool = false
    ) {
        self.result = result
        self.shouldFail = shouldFail
    }

    func generateResumeEvaluation(
        from resumeText: String
    ) async throws -> InterviewEvaluation {
        result
    }

    func generateSuggestions(
        from transcript: [TranscriptLine],
        resumeText: String?
    ) async throws -> [InterviewSuggestion] {
        []
    }

    func generateEvaluation(
        from transcript: [TranscriptLine],
        resumeText: String?
    ) async throws -> InterviewEvaluation {
        try await generateEvaluation(
            from: transcript,
            resumeText: resumeText,
            customRequirement: nil
        )
    }

    func generateEvaluation(
        from transcript: [TranscriptLine],
        resumeText: String?,
        customRequirement: String?
    ) async throws -> InterviewEvaluation {
        guard !shouldFail else { throw StubError.failed }
        capturedTranscript = transcript
        capturedResume = resumeText
        capturedRequirement = customRequirement
        return result
    }

    func snapshot() -> (
        transcriptCount: Int,
        resumeText: String?,
        requirement: String?
    ) {
        (
            capturedTranscript.count,
            capturedResume,
            capturedRequirement
        )
    }
}

enum HistoricalEvaluationRegeneratorTests {
    static let all = [
        TestCase(name: "历史评价会读取原逐字稿和简历重新生成") {
            let directory = temporaryDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            try writeTranscript(in: directory)
            try "候选人简历".write(
                to: directory.appendingPathComponent("resume.txt"),
                atomically: true,
                encoding: .utf8
            )
            try "旧评价".write(
                to: evaluationURL(in: directory),
                atomically: true,
                encoding: .utf8
            )
            let expected = InterviewEvaluation(
                markdown: "## 结论\n保留复核\n## 综合评分\n68/100"
            )
            let provider = HistoricalProviderStub(result: expected)
            let regenerator = HistoricalEvaluationRegenerator(
                providerFactory: { _ in provider }
            )

            let result = try await regenerator.regenerate(
                in: directory,
                customRequirement: "重点检查回答逻辑"
            )

            try expect(
                result.markdown == expected.markdown,
                "应返回新评价"
            )
            try expect(
                result.rulesConfiguration != nil,
                "返回结果应带实际使用的规则"
            )
            let captured = await provider.snapshot()
            try expect(
                captured.transcriptCount == 2,
                "应读取完整结构化逐字稿"
            )
            try expect(
                captured.resumeText == "候选人简历",
                "应传入该场简历"
            )
            try expect(
                captured.requirement == "重点检查回答逻辑",
                "应传入自定义要求"
            )
            let saved = try String(
                contentsOf: evaluationURL(in: directory),
                encoding: .utf8
            )
            try expect(saved == expected.markdown, "应保存新评价")
        },
        TestCase(name: "历史场次缺少逐字稿时保留旧评价") {
            let directory = temporaryDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            try "旧评价".write(
                to: evaluationURL(in: directory),
                atomically: true,
                encoding: .utf8
            )
            let provider = HistoricalProviderStub(
                result: InterviewEvaluation(markdown: "新评价")
            )
            let regenerator = HistoricalEvaluationRegenerator(
                providerFactory: { _ in provider }
            )

            var didThrow = false
            do {
                _ = try await regenerator.regenerate(
                    in: directory,
                    customRequirement: nil
                )
            } catch {
                didThrow = true
            }
            try expect(didThrow, "缺少逐字稿应失败")
            let saved = try String(
                contentsOf: evaluationURL(in: directory),
                encoding: .utf8
            )
            try expect(saved == "旧评价", "不应覆盖旧评价")
        },
        TestCase(name: "历史评价生成失败时保留旧评价") {
            let directory = temporaryDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            try writeTranscript(in: directory)
            try "旧评价".write(
                to: evaluationURL(in: directory),
                atomically: true,
                encoding: .utf8
            )
            let provider = HistoricalProviderStub(
                result: InterviewEvaluation(markdown: "新评价"),
                shouldFail: true
            )
            let regenerator = HistoricalEvaluationRegenerator(
                providerFactory: { _ in provider }
            )

            var didThrow = false
            do {
                _ = try await regenerator.regenerate(
                    in: directory,
                    customRequirement: nil
                )
            } catch {
                didThrow = true
            }
            try expect(didThrow, "模拟生成失败应向上抛出")
            let saved = try String(
                contentsOf: evaluationURL(in: directory),
                encoding: .utf8
            )
            try expect(saved == "旧评价", "失败时不应覆盖旧评价")
        },
        TestCase(name: "重新评价优先使用后来添加的简历") {
            let directory = temporaryDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            try writeTranscript(in: directory)
            try "旧简历".write(
                to: directory.appendingPathComponent("resume.txt"),
                atomically: true,
                encoding: .utf8
            )
            let source = directory.appendingPathComponent("candidate.pdf")
            try Data("源文件".utf8).write(to: source)
            _ = try CurrentResumeStore(
                root: directory.appendingPathComponent(
                    "AttachedResume",
                    isDirectory: true
                )
            ).save(
                sourceURL: source,
                text: "后来添加的简历"
            )
            let provider = HistoricalProviderStub(
                result: InterviewEvaluation(markdown: "新评价")
            )
            let regenerator = HistoricalEvaluationRegenerator(
                providerFactory: { _ in provider }
            )

            _ = try await regenerator.regenerate(
                in: directory,
                customRequirement: nil
            )

            let captured = await provider.snapshot()
            try expect(
                captured.resumeText == "后来添加的简历",
                "重新评价应使用新添加的简历"
            )
        },
        TestCase(name: "历史评价成功后保存当前规则快照") {
            let directory = temporaryDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            try writeTranscript(in: directory)
            let rulesRoot = directory.appendingPathComponent(
                "RuleStore",
                isDirectory: true
            )
            let rulesStore = EvaluationRulesStore(root: rulesRoot)
            var rules = EvaluationRulesConfiguration.default
            rules.interview.dimensions[0].instruction = "重点检查结论"
            try rulesStore.save(rules)
            let provider = HistoricalProviderStub(
                result: InterviewEvaluation(markdown: "新评价")
            )
            let regenerator = HistoricalEvaluationRegenerator(
                rulesStore: rulesStore,
                providerFactory: { _ in provider }
            )

            _ = try await regenerator.regenerate(
                in: directory,
                customRequirement: nil
            )

            let snapshot = try JSONDecoder().decode(
                EvaluationRulesConfiguration.self,
                from: Data(
                    contentsOf: directory.appendingPathComponent(
                        "evaluation-rules.json"
                    )
                )
            )
            try expect(snapshot == rules, "应保存当前评价规则快照")
        }
    ]

    private static func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    private static func evaluationURL(in directory: URL) -> URL {
        directory.appendingPathComponent("evaluation-report.md")
    }

    private static func writeTranscript(in directory: URL) throws {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let lines = [
            TranscriptLine(
                source: .system,
                startTime: 1,
                endTime: 3,
                text: "我负责数据产品。"
            ),
            TranscriptLine(
                source: .microphone,
                startTime: 4,
                endTime: 6,
                text: "请说明具体结果。"
            )
        ]
        let encoder = JSONEncoder()
        var data = Data()
        for line in lines {
            data.append(try encoder.encode(line))
            data.append(0x0A)
        }
        try data.write(
            to: directory.appendingPathComponent("transcript.jsonl"),
            options: .atomic
        )
    }
}
