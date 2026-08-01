import Foundation

public struct EvaluationArtifactStore: Sendable {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public func save(
        _ evaluation: InterviewEvaluation,
        reportName: String,
        snapshotName: String
    ) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let reportURL = directory.appendingPathComponent(reportName)
        let snapshotURL = directory.appendingPathComponent(snapshotName)
        let reportData = Data(evaluation.markdown.utf8)
        let snapshotData: Data?
        if let rules = evaluation.rulesConfiguration {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            snapshotData = try encoder.encode(rules)
        } else {
            snapshotData = nil
        }

        let artifact = StoredEvaluationArtifact(
            schemaVersion: 1,
            evaluation: evaluation
        )
        let artifactData = try JSONEncoder().encode(artifact)
        try artifactData.write(
            to: artifactURL(reportName: reportName),
            options: .atomic
        )

        // These two files remain human-readable compatibility exports.
        // The app always reads the single atomic artifact above first.
        try? reportData.write(to: reportURL, options: .atomic)
        if let snapshotData {
            try? snapshotData.write(to: snapshotURL, options: .atomic)
        } else if fileManager.fileExists(atPath: snapshotURL.path) {
            try? fileManager.removeItem(at: snapshotURL)
        }
    }

    public func load(
        reportName: String,
        snapshotName: String
    ) throws -> InterviewEvaluation? {
        let artifactURL = artifactURL(reportName: reportName)
        if FileManager.default.fileExists(atPath: artifactURL.path) {
            let artifact = try JSONDecoder().decode(
                StoredEvaluationArtifact.self,
                from: Data(contentsOf: artifactURL)
            )
            return artifact.evaluation
        }

        let reportURL = directory.appendingPathComponent(reportName)
        guard FileManager.default.fileExists(atPath: reportURL.path) else {
            return nil
        }
        let markdown = try String(contentsOf: reportURL, encoding: .utf8)
        let snapshotURL = directory.appendingPathComponent(snapshotName)
        let configuration = try? JSONDecoder().decode(
            EvaluationRulesConfiguration.self,
            from: Data(contentsOf: snapshotURL)
        )
        return InterviewEvaluation(
            markdown: markdown,
            rulesConfiguration: configuration
        )
    }

    public func artifactURL(reportName: String) -> URL {
        let base = (reportName as NSString)
            .deletingPathExtension
        return directory.appendingPathComponent(
            "\(base).artifact.json"
        )
    }
}

private struct StoredEvaluationArtifact: Codable {
    let schemaVersion: Int
    let evaluation: InterviewEvaluation

    init(schemaVersion: Int, evaluation: InterviewEvaluation) {
        self.schemaVersion = schemaVersion
        self.evaluation = evaluation
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(
            keyedBy: CodingKeys.self
        )
        let schemaVersion = try values.decode(
            Int.self,
            forKey: .schemaVersion
        )
        guard schemaVersion == 1 else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: values,
                debugDescription: "不支持的评价产物版本"
            )
        }
        self.schemaVersion = schemaVersion
        evaluation = try values.decode(
            InterviewEvaluation.self,
            forKey: .evaluation
        )
    }
}
