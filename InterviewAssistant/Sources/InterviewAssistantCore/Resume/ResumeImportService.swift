import Foundation

public struct ResumeImportResult: Sendable {
    public let document: ResumeDocument
    public let evaluation: InterviewEvaluation?
    public let warning: String?

    public init(
        document: ResumeDocument,
        evaluation: InterviewEvaluation?,
        warning: String?
    ) {
        self.document = document
        self.evaluation = evaluation
        self.warning = warning
    }
}

public protocol ResumeImportServicing: Sendable {
    func importResume(from url: URL) async throws -> ResumeImportResult
    func refreshEvaluation() async throws -> InterviewEvaluation
    func restore() async throws -> ResumeImportResult?
    func clear() async throws
}

public actor ResumeImportService: ResumeImportServicing {
    public typealias ProviderFactory =
        @Sendable (URL) throws -> any InterviewAnalysisProvider

    private let extractor: any ResumeTextExtracting
    private let store: CurrentResumeStore
    private let providerFactory: ProviderFactory

    public init(
        extractor: any ResumeTextExtracting = ResumeTextExtractor(),
        store: CurrentResumeStore = CurrentResumeStore(),
        providerFactory: @escaping ProviderFactory
    ) {
        self.extractor = extractor
        self.store = store
        self.providerFactory = providerFactory
    }

    public func importResume(
        from url: URL
    ) async throws -> ResumeImportResult {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let text = try await extractor.extractText(from: url)
        let document = try store.save(sourceURL: url, text: text)

        do {
            let provider = try providerFactory(store.root)
            let evaluation = try await provider
                .generateResumeEvaluation(from: text)
            try store.saveEvaluation(evaluation)
            return ResumeImportResult(
                document: document,
                evaluation: evaluation,
                warning: nil
            )
        } catch {
            return ResumeImportResult(
                document: document,
                evaluation: nil,
                warning: "简历已保存，初评生成失败："
                    + error.localizedDescription
            )
        }
    }

    public func restore() async throws -> ResumeImportResult? {
        guard let document = try store.load() else { return nil }
        return ResumeImportResult(
            document: document,
            evaluation: try store.loadEvaluation(),
            warning: nil
        )
    }

    public func refreshEvaluation() async throws -> InterviewEvaluation {
        guard let document = try store.load() else {
            throw CocoaError(.fileNoSuchFile)
        }
        let provider = try providerFactory(store.root)
        let evaluation = try await provider.generateResumeEvaluation(
            from: document.text
        )
        try store.saveEvaluation(evaluation)
        return evaluation
    }

    public func clear() async throws {
        try store.clear()
    }
}
