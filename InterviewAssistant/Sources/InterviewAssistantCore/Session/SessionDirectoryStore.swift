import Foundation

public struct SessionDirectoryStore: Sendable {
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
                .appendingPathComponent("InterviewAssistant", isDirectory: true)
                .appendingPathComponent("Sessions", isDirectory: true)
        }
    }

    public func createSessionDirectory(now: Date = Date()) throws -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "yyyyMMdd-HHmmss"

        let name =
            "\(formatter.string(from: now))-\(UUID().uuidString.lowercased())"
        let directory = root.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }
}
