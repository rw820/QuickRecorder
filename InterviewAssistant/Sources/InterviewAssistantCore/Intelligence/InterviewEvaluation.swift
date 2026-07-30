public struct InterviewEvaluation: Codable, Equatable, Sendable {
    public let markdown: String

    public init(markdown: String) {
        self.markdown = markdown
    }

    public var hasRequiredSections: Bool {
        ["## 总评", "## 优势", "## 劣势", "## 风险"]
            .allSatisfy(markdown.contains)
    }
}
