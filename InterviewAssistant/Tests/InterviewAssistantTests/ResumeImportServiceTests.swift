import Foundation
import InterviewAssistantCore

private struct ResumeExtractorStub: ResumeTextExtracting {
    let text: String

    func extractText(from url: URL) async throws -> String {
        text
    }
}

private struct ResumeProviderStub: InterviewAnalysisProvider {
    func generateResumeEvaluation(
        from resumeText: String
    ) async throws -> InterviewEvaluation {
        InterviewEvaluation(
            markdown: "## 总评\nA\n## 优势\nB\n## 劣势\nC\n## 风险\nD"
        )
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
        InterviewEvaluation(
            markdown: "## 总评\nA\n## 优势\nB\n## 劣势\nC\n## 风险\nD"
        )
    }
}

private actor SequencedResumeProvider: InterviewAnalysisProvider {
    private var evaluations: [InterviewEvaluation]
    private var latestCustomRequirement: String?

    init(evaluations: [InterviewEvaluation]) {
        self.evaluations = evaluations
    }

    func generateResumeEvaluation(
        from resumeText: String
    ) async throws -> InterviewEvaluation {
        evaluations.removeFirst()
    }

    func generateResumeEvaluation(
        from resumeText: String,
        customRequirement: String?
    ) async throws -> InterviewEvaluation {
        latestCustomRequirement = customRequirement
        return evaluations.removeFirst()
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
        evaluations[0]
    }

    func capturedRequirement() -> String? {
        latestCustomRequirement
    }
}

enum ResumeImportServiceTests {
    static let all = [
        TestCase(name: "导入简历后自动生成并保存初评") {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            let source = directory.appendingPathComponent("candidate.pdf")
            defer { try? FileManager.default.removeItem(at: directory) }
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            try Data([1, 2, 3]).write(to: source)

            let store = CurrentResumeStore(
                root: directory.appendingPathComponent(
                    "CurrentCandidate",
                    isDirectory: true
                )
            )
            let service = ResumeImportService(
                extractor: ResumeExtractorStub(
                    text: "候选人拥有八年数据产品经验。"
                ),
                store: store,
                providerFactory: { _ in ResumeProviderStub() }
            )

            let result = try await service.importResume(from: source)

            try expect(
                result.document.text.contains("八年"),
                "应保存提取后的文字"
            )
            try expect(
                result.evaluation?.hasRequiredSections == true,
                "应自动生成四段初评"
            )
            let storedEvaluation = try store.loadEvaluation()
            try expect(
                storedEvaluation != nil,
                "初评应保存到本机"
            )
        },
        TestCase(name: "刷新会重新生成并覆盖简历初评") {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            let source = directory.appendingPathComponent("candidate.txt")
            defer { try? FileManager.default.removeItem(at: directory) }
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            try Data("简历".utf8).write(to: source)

            let first = InterviewEvaluation(
                markdown: "## 总评\n旧\n## 优势\n旧\n## 劣势\n旧\n## 风险\n旧"
            )
            let refreshed = InterviewEvaluation(
                markdown: "## 总评\n新\n## 优势\n新\n## 劣势\n新\n## 风险\n新"
            )
            let provider = SequencedResumeProvider(
                evaluations: [first, refreshed]
            )
            let store = CurrentResumeStore(
                root: directory.appendingPathComponent("CurrentCandidate")
            )
            let service = ResumeImportService(
                extractor: ResumeExtractorStub(text: "候选人简历文字"),
                store: store,
                providerFactory: { _ in provider }
            )

            _ = try await service.importResume(from: source)
            let result = try await service.refreshEvaluation(
                customRequirement: "重点核对管理报表经验"
            )
            let storedEvaluation = try store.loadEvaluation()
            let capturedRequirement = await provider.capturedRequirement()

            try expect(result == refreshed, "刷新应返回新评价")
            try expect(
                storedEvaluation == refreshed,
                "刷新应覆盖本机评价文件"
            )
            try expect(
                capturedRequirement == "重点核对管理报表经验",
                "刷新要求应传给分析服务"
            )
        }
    ]
}
