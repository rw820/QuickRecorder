import Foundation

public struct CurrentResumeStore: Sendable {
    public let root: URL

    public init(root: URL? = nil) {
        if let root {
            self.root = root
        } else {
            let support = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            )[0]
            self.root = support
                .appendingPathComponent(
                    "InterviewAssistant",
                    isDirectory: true
                )
                .appendingPathComponent(
                    "CurrentCandidate",
                    isDirectory: true
                )
        }
    }

    public func save(
        sourceURL: URL,
        text: String,
        importedAt: Date = Date()
    ) throws -> ResumeDocument {
        let cleaned = text.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !cleaned.isEmpty else {
            throw CurrentResumeStoreError.emptyText
        }

        let fileManager = FileManager.default
        let parent = root.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: parent,
            withIntermediateDirectories: true
        )

        let token = UUID().uuidString
        let staging = parent.appendingPathComponent(
            ".CurrentCandidate-staging-\(token)",
            isDirectory: true
        )
        let backup = parent.appendingPathComponent(
            ".CurrentCandidate-backup-\(token)",
            isDirectory: true
        )
        try fileManager.createDirectory(
            at: staging,
            withIntermediateDirectories: true
        )

        let fileExtension = sourceURL.pathExtension.lowercased()
        let storedName = fileExtension.isEmpty
            ? "original"
            : "original.\(fileExtension)"
        let stagedOriginal = staging.appendingPathComponent(storedName)
        let finalOriginal = root.appendingPathComponent(storedName)

        do {
            try fileManager.copyItem(
                at: sourceURL,
                to: stagedOriginal
            )
            try cleaned.write(
                to: staging.appendingPathComponent("resume.txt"),
                atomically: true,
                encoding: .utf8
            )
            let document = ResumeDocument(
                originalFileName: sourceURL.lastPathComponent,
                text: cleaned,
                importedAt: importedAt,
                localFileURL: finalOriginal
            )
            let metadata = try JSONEncoder().encode(document)
            try metadata.write(
                to: staging.appendingPathComponent(
                    "resume-metadata.json"
                ),
                options: .atomic
            )

            if fileManager.fileExists(atPath: root.path) {
                try fileManager.moveItem(at: root, to: backup)
            }
            do {
                try fileManager.moveItem(at: staging, to: root)
                try? fileManager.removeItem(at: backup)
            } catch {
                if fileManager.fileExists(atPath: backup.path) {
                    try? fileManager.moveItem(at: backup, to: root)
                }
                throw error
            }
            return document
        } catch {
            try? fileManager.removeItem(at: staging)
            throw error
        }
    }

    public func load() throws -> ResumeDocument? {
        let url = root.appendingPathComponent("resume-metadata.json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return try JSONDecoder().decode(
            ResumeDocument.self,
            from: Data(contentsOf: url)
        )
    }

    public func saveEvaluation(
        _ evaluation: InterviewEvaluation
    ) throws {
        try EvaluationArtifactStore(directory: root).save(
            evaluation,
            reportName: "resume-evaluation.md",
            snapshotName: "resume-evaluation-rules.json"
        )
    }

    public func loadEvaluation() throws -> InterviewEvaluation? {
        try EvaluationArtifactStore(directory: root).load(
            reportName: "resume-evaluation.md",
            snapshotName: "resume-evaluation-rules.json"
        )
    }

    public func copyArtifacts(to directory: URL) throws {
        guard try load() != nil else { return }
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        for name in [
            "resume.txt",
            "resume-evaluation.md",
            "resume-evaluation-rules.json",
            "resume-evaluation.artifact.json",
            "resume-metadata.json",
        ] {
            let source = root.appendingPathComponent(name)
            guard fileManager.fileExists(atPath: source.path) else {
                continue
            }
            let destination = directory.appendingPathComponent(name)
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: source, to: destination)
        }
    }

    public func clear() throws {
        guard FileManager.default.fileExists(atPath: root.path) else {
            return
        }
        try FileManager.default.removeItem(at: root)
    }
}

public enum CurrentResumeStoreError: LocalizedError {
    case emptyText

    public var errorDescription: String? {
        switch self {
        case .emptyText:
            "简历中没有可保存的文字"
        }
    }
}
