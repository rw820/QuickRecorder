import Foundation

public protocol HistoricalResumeAttaching: Sendable {
    func attachResume(
        from sourceURL: URL,
        to sessionDirectory: URL
    ) async throws -> ResumeDocument
}

public actor HistoricalResumeAttachmentService:
    HistoricalResumeAttaching
{
    private let extractor: any ResumeTextExtracting

    public init(
        extractor: any ResumeTextExtracting = ResumeTextExtractor()
    ) {
        self.extractor = extractor
    }

    public func attachResume(
        from sourceURL: URL,
        to sessionDirectory: URL
    ) async throws -> ResumeDocument {
        let hasAccess =
            sourceURL.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let text = try await extractor.extractText(from: sourceURL)
        let store = CurrentResumeStore(
            root: sessionDirectory.appendingPathComponent(
                "AttachedResume",
                isDirectory: true
            )
        )
        return try store.save(sourceURL: sourceURL, text: text)
    }
}
