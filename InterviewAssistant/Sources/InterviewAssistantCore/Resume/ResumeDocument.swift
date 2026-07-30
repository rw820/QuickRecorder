import Foundation

public struct ResumeDocument:
    Codable,
    Equatable,
    Identifiable,
    Sendable
{
    public let id: UUID
    public let originalFileName: String
    public let text: String
    public let importedAt: Date
    public let localFileURL: URL

    public init(
        id: UUID = UUID(),
        originalFileName: String,
        text: String,
        importedAt: Date = Date(),
        localFileURL: URL
    ) {
        self.id = id
        self.originalFileName = originalFileName
        self.text = text
        self.importedAt = importedAt
        self.localFileURL = localFileURL
    }
}
