public struct InterviewEvaluation: Codable, Equatable, Sendable {
    public let markdown: String
    public let rulesConfiguration: EvaluationRulesConfiguration?

    public init(
        markdown: String,
        rulesConfiguration: EvaluationRulesConfiguration? = nil
    ) {
        self.markdown = markdown
        self.rulesConfiguration = rulesConfiguration
    }

    public var hasRequiredSections: Bool {
        ["## 总评", "## 优势", "## 劣势", "## 风险"]
            .allSatisfy(markdown.contains)
    }
}
