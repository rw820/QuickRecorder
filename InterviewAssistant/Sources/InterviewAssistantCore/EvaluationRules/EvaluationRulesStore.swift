import Foundation

public struct EvaluationRulesStore: Sendable {
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
                    "EvaluationRules",
                    isDirectory: true
                )
        }
    }

    public func load() -> EvaluationRulesConfiguration {
        for name in ["current.json", "last-valid.json"] {
            let url = root.appendingPathComponent(name)
            guard
                let data = try? Data(contentsOf: url),
                let rules = try? JSONDecoder().decode(
                    EvaluationRulesConfiguration.self,
                    from: data
                ),
                (try? EvaluationRulesValidator.validate(rules)) != nil
            else {
                continue
            }
            return rules
        }
        return .default
    }

    public func save(
        _ rules: EvaluationRulesConfiguration
    ) throws {
        try EvaluationRulesValidator.validate(rules)
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        let current = root.appendingPathComponent("current.json")
        let backup = root.appendingPathComponent("last-valid.json")
        if
            let existing = try? Data(contentsOf: current),
            let decoded = try? JSONDecoder().decode(
                EvaluationRulesConfiguration.self,
                from: existing
            ),
            (try? EvaluationRulesValidator.validate(decoded)) != nil
        {
            try existing.write(to: backup, options: .atomic)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(rules).write(to: current, options: .atomic)
    }

    @discardableResult
    public func restoreDefault() throws -> EvaluationRulesConfiguration {
        let rules = EvaluationRulesConfiguration.default
        try save(rules)
        return rules
    }
}
