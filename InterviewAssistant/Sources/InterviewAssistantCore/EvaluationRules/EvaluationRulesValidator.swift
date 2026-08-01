import Foundation

public struct EvaluationRulesValidationError: LocalizedError, Equatable {
    public let message: String

    public init(_ message: String) {
        self.message = message
    }

    public var errorDescription: String? { message }
}

public enum EvaluationRulesValidator {
    public static func validate(
        _ configuration: EvaluationRulesConfiguration
    ) throws {
        guard configuration.schemaVersion > 0 else {
            throw EvaluationRulesValidationError("规则版本无效")
        }
        try validateInterview(configuration.interview)
        try validateResume(configuration.resume)
    }

    private static func validateInterview(
        _ rules: InterviewEvaluationRules
    ) throws {
        guard !rules.dimensions.isEmpty else {
            throw EvaluationRulesValidationError("至少保留一个评分维度")
        }
        try validateUnique(
            rules.dimensions.map(\.id),
            label: "评分维度 ID"
        )
        try validateUnique(
            rules.dimensions.map(\.title),
            label: "评分维度名称"
        )
        for dimension in rules.dimensions {
            guard dimension.maximum > 0 else {
                throw EvaluationRulesValidationError(
                    "评分维度“\(dimension.title)”的分值必须大于0"
                )
            }
            try validateRange(
                minimum: dimension.reasonMinimumCharacters,
                maximum: dimension.reasonMaximumCharacters,
                label: "评分维度“\(dimension.title)”理由长度"
            )
        }
        guard rules.dimensions.map(\.maximum).reduce(0, +) == 100 else {
            throw EvaluationRulesValidationError("评分维度满分合计必须为100")
        }
        guard
            (1...100).contains(rules.thresholds.recommendedMinimum),
            (0...99).contains(rules.thresholds.reviewMinimum),
            rules.thresholds.recommendedMinimum
                > rules.thresholds.reviewMinimum
        else {
            throw EvaluationRulesValidationError(
                "建议通过线必须高于保留复核通过线"
            )
        }
        try validateSections(
            rules.sections,
            requiredKinds: [
                .conclusion, .totalScore, .dimensionScores,
                .summary
            ]
        )
        guard rules.sections.first(
            where: { $0.kind == .dimensionScores }
        )?.maximumItems == rules.dimensions.count else {
            throw EvaluationRulesValidationError(
                "分项评分条数必须与评分维度数量一致"
            )
        }
        guard rules.sections.first(
            where: { $0.kind == .conclusion }
        )?.maximumItems == 3 else {
            throw EvaluationRulesValidationError("结论固定为三行")
        }
        guard let total = rules.sections.first(
            where: { $0.kind == .totalScore }
        ), total.maximumItems == 1,
            total.minimumCharacters == 1,
            total.maximumCharacters == 10
        else {
            throw EvaluationRulesValidationError("综合评分固定为一行")
        }
        if rules.promptMode == .advanced {
            try requireVariables(
                ["{{transcript}}", "{{outputContract}}"],
                in: rules.advancedPromptTemplate,
                label: "面试高级提示词"
            )
        }
    }

    private static func validateResume(
        _ rules: ResumeEvaluationRules
    ) throws {
        guard rules.questionCount > 0 else {
            throw EvaluationRulesValidationError("建议问题数量必须大于0")
        }
        try validateSections(
            rules.sections,
            requiredKinds: [.summary, .questions]
        )
        guard rules.sections.first(
            where: { $0.kind == .questions }
        )?.maximumItems == rules.questionCount else {
            throw EvaluationRulesValidationError(
                "建议问题数量必须与固定问题数量一致"
            )
        }
        if rules.promptMode == .advanced {
            try requireVariables(
                ["{{resume}}", "{{outputContract}}"],
                in: rules.advancedPromptTemplate,
                label: "简历高级提示词"
            )
        }
    }

    private static func validateSections(
        _ sections: [EvaluationSectionRule],
        requiredKinds: Set<EvaluationSectionKind>
    ) throws {
        try validateUnique(sections.map(\.id), label: "输出板块 ID")
        try validateUnique(sections.map(\.title), label: "输出板块标题")
        let kinds = Set(sections.map(\.kind))
        for required in requiredKinds where !kinds.contains(required) {
            throw EvaluationRulesValidationError(
                "缺少必需输出板块：\(required.rawValue)"
            )
        }
        for section in sections {
            guard section.maximumItems > 0 else {
                throw EvaluationRulesValidationError(
                    "板块“\(section.title)”条数必须大于0"
                )
            }
            try validateRange(
                minimum: section.minimumCharacters,
                maximum: section.maximumCharacters,
                label: "板块“\(section.title)”内容长度"
            )
        }
    }

    private static func validateRange(
        minimum: Int,
        maximum: Int,
        label: String
    ) throws {
        guard minimum >= 0, maximum > 0, minimum <= maximum else {
            throw EvaluationRulesValidationError(
                "\(label)设置无效"
            )
        }
    }

    private static func validateUnique(
        _ values: [String],
        label: String
    ) throws {
        let cleaned = values.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !cleaned.contains(where: \.isEmpty) else {
            throw EvaluationRulesValidationError("\(label)不能为空")
        }
        if cleaned.contains(where: {
            $0.contains("\n") || $0.contains("\r")
        }) {
            throw EvaluationRulesValidationError("\(label)不能包含换行")
        }
        if label.contains("名称") || label.contains("标题") {
            let forbidden = CharacterSet(charactersIn: "：:#")
            if cleaned.contains(where: {
                $0.rangeOfCharacter(from: forbidden) != nil
            }) {
                throw EvaluationRulesValidationError(
                    "\(label)不能包含格式分隔符：、: 或 #"
                )
            }
        }
        guard Set(cleaned).count == cleaned.count else {
            throw EvaluationRulesValidationError("\(label)不能重复")
        }
    }

    private static func requireVariables(
        _ variables: [String],
        in template: String,
        label: String
    ) throws {
        for variable in variables where !template.contains(variable) {
            let readable = variable
                .replacingOccurrences(of: "{{", with: "")
                .replacingOccurrences(of: "}}", with: "")
            throw EvaluationRulesValidationError(
                "\(label)缺少变量 \(readable)"
            )
        }
    }
}
