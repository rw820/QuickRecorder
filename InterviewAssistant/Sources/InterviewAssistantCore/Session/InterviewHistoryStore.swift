import Foundation

public struct InterviewHistoryStore: Sendable {
    public let root: URL

    public init(root: URL? = nil) {
        self.root = root ?? SessionDirectoryStore().root
    }

    public func load() -> [InterviewHistoryRecord] {
        let fileManager = FileManager.default
        guard
            let directories = try? fileManager.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
        else {
            return []
        }

        return directories
            .compactMap { directory -> InterviewHistoryRecord? in
                guard
                    (try? directory.resourceValues(
                        forKeys: [.isDirectoryKey]
                    ).isDirectory) == true,
                    let startedAt = Self.sessionDate(
                        from: directory.lastPathComponent
                    )
                else {
                    return nil
                }
                return makeRecord(
                    directory: directory,
                    startedAt: startedAt
                )
            }
            .sorted {
                if $0.startedAt == $1.startedAt {
                    return $0.id > $1.id
                }
                return $0.startedAt > $1.startedAt
            }
    }

    private func makeRecord(
        directory: URL,
        startedAt: Date
    ) -> InterviewHistoryRecord {
        let metadata = readMetadata(in: directory)
        let resumeFileName = metadata?.originalFileName
        let displayName =
            resumeFileName
            ?? "面试 \(Self.displayDateFormatter.string(from: startedAt))"

        return InterviewHistoryRecord(
            id: directory.lastPathComponent,
            directory: directory,
            startedAt: startedAt,
            displayName: displayName,
            resumeFileName: resumeFileName,
            resumeText: readText(named: "resume.txt", in: directory),
            evaluation: readText(
                named: "evaluation-report.md",
                in: directory
            ),
            transcript: readText(named: "transcript.md", in: directory),
            systemAudioURL: existingFile(
                named: "system.caf",
                in: directory
            ),
            microphoneAudioURL: existingFile(
                named: "microphone.caf",
                in: directory
            )
        )
    }

    private func readMetadata(in directory: URL) -> ResumeDocument? {
        let url = directory.appendingPathComponent(
            "resume-metadata.json"
        )
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ResumeDocument.self, from: data)
    }

    private func readText(named name: String, in directory: URL) -> String? {
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

    private func existingFile(named name: String, in directory: URL) -> URL? {
        let url = directory.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return url
    }

    private static func sessionDate(from name: String) -> Date? {
        guard name.count >= 15 else { return nil }
        return sessionDateFormatter.date(
            from: String(name.prefix(15))
        )
    }

    private static let sessionDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()

    private static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        return formatter
    }()
}
