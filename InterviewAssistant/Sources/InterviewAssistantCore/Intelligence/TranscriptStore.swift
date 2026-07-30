import Foundation

public final class TranscriptStore: @unchecked Sendable {
    public let directory: URL

    private let queue = DispatchQueue(
        label: "local.ben.InterviewAssistant.transcript-store"
    )
    private var lines: [TranscriptLine] = []
    private let encoder = JSONEncoder()

    public init(directory: URL) throws {
        self.directory = directory
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        try Data().write(to: jsonlURL, options: .atomic)
    }

    public func append(_ line: TranscriptLine) throws {
        try queue.sync {
            lines.append(line)
            var data = try encoder.encode(line)
            data.append(0x0A)

            let handle = try FileHandle(forWritingTo: jsonlURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        }
    }

    public func snapshot() -> [TranscriptLine] {
        queue.sync { lines.sorted(by: Self.order) }
    }

    public func finish() throws {
        try queue.sync {
            let body = lines
                .sorted(by: Self.order)
                .map(\.displayText)
                .joined(separator: "\n\n")
            let markdown = "# 面试逐字稿\n\n\(body)\n"
            try markdown.write(
                to: markdownURL,
                atomically: true,
                encoding: .utf8
            )
        }
    }

    private var jsonlURL: URL {
        directory.appendingPathComponent("transcript.jsonl")
    }

    private var markdownURL: URL {
        directory.appendingPathComponent("transcript.md")
    }

    private static func order(
        _ lhs: TranscriptLine,
        _ rhs: TranscriptLine
    ) -> Bool {
        if lhs.startTime == rhs.startTime {
            return lhs.source.rawValue < rhs.source.rawValue
        }
        return lhs.startTime < rhs.startTime
    }
}
