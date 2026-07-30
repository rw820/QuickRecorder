import Foundation

public enum HistoricalEvaluationRegenerationError: LocalizedError {
    case transcriptMissing
    case transcriptInvalid

    public var errorDescription: String? {
        switch self {
        case .transcriptMissing:
            "该场面试没有可用的逐字稿"
        case .transcriptInvalid:
            "该场面试的逐字稿无法读取"
        }
    }
}

public protocol HistoricalEvaluationRegenerating: Sendable {
    func regenerate(
        in directory: URL,
        customRequirement: String?
    ) async throws -> InterviewEvaluation
}

public struct HistoricalEvaluationRegenerator:
    HistoricalEvaluationRegenerating,
    Sendable
{
    public typealias ProviderFactory =
        @Sendable (URL) throws -> any InterviewAnalysisProvider

    private let providerFactory: ProviderFactory

    public init(
        providerFactory: @escaping ProviderFactory = {
            try CodexCLIProvider(sessionDirectory: $0)
        }
    ) {
        self.providerFactory = providerFactory
    }

    public func regenerate(
        in directory: URL,
        customRequirement: String?
    ) async throws -> InterviewEvaluation {
        let transcript = try loadTranscript(in: directory)
        let resumeText = readOptionalText(
            named: "resume.txt",
            in: directory
        )
        let provider = try providerFactory(directory)
        let evaluation = try await provider.generateEvaluation(
            from: transcript,
            resumeText: resumeText,
            customRequirement: customRequirement
        )
        try evaluation.markdown.write(
            to: directory.appendingPathComponent(
                "evaluation-report.md"
            ),
            atomically: true,
            encoding: .utf8
        )
        return evaluation
    }

    private func loadTranscript(
        in directory: URL
    ) throws -> [TranscriptLine] {
        let url = directory.appendingPathComponent("transcript.jsonl")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw HistoricalEvaluationRegenerationError.transcriptMissing
        }
        let text: String
        do {
            text = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw HistoricalEvaluationRegenerationError.transcriptInvalid
        }
        let rows = text.split(
            whereSeparator: \.isNewline
        )
        guard !rows.isEmpty else {
            throw HistoricalEvaluationRegenerationError.transcriptMissing
        }
        let decoder = JSONDecoder()
        do {
            return try rows.map {
                try decoder.decode(
                    TranscriptLine.self,
                    from: Data($0.utf8)
                )
            }
        } catch {
            throw HistoricalEvaluationRegenerationError.transcriptInvalid
        }
    }

    private func readOptionalText(
        named name: String,
        in directory: URL
    ) -> String? {
        let url = directory.appendingPathComponent(name)
        guard
            let text = try? String(contentsOf: url, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines),
            !text.isEmpty
        else {
            return nil
        }
        return text
    }
}
