import Foundation

public enum InterviewRecommendation: Int, Sendable, Comparable {
    case notRecommended = 0
    case review = 1
    case recommended = 2

    public var title: String {
        switch self {
        case .recommended:
            "建议通过"
        case .review:
            "保留复核"
        case .notRecommended:
            "不建议通过"
        }
    }

    public static func < (
        lhs: InterviewRecommendation,
        rhs: InterviewRecommendation
    ) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    static func parse(_ value: String) -> InterviewRecommendation? {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "建议通过":
            .recommended
        case "保留复核":
            .review
        case "不建议通过":
            .notRecommended
        default:
            nil
        }
    }
}

public enum InterviewEvaluationConfidence: String, Sendable {
    case high = "高"
    case medium = "中"
    case low = "低"
}

public struct InterviewEvaluationDimension: Equatable, Sendable {
    public let title: String
    public let score: Int
    public let maximum: Int
    public let reason: String
}

public struct InterviewEvaluationScorecard: Equatable, Sendable {
    public let recommendation: InterviewRecommendation
    public let confidence: InterviewEvaluationConfidence
    public let reason: String
    public let totalScore: Int
    public let dimensions: [InterviewEvaluationDimension]
    public let logicFindings: [String]

    public static func parse(
        from markdown: String
    ) -> InterviewEvaluationScorecard? {
        parse(
            from: markdown,
            rules: CompactInterviewEvaluation.legacyCompatibleRules
        )
    }

    public static func parse(
        from markdown: String,
        rules: InterviewEvaluationRules
    ) -> InterviewEvaluationScorecard? {
        let conclusionTitle = title(
            for: .conclusion,
            in: rules,
            fallback: "结论"
        )
        let conclusionText = CompactInterviewEvaluation.section(
            conclusionTitle,
            in: markdown
        )
        guard let conclusionRule = rules.sections.first(
            where: { $0.kind == .conclusion }
        ), Self.isValidLength(conclusionText, rule: conclusionRule) else {
            return nil
        }
        let conclusion = CompactInterviewEvaluation.items(
            in: conclusionText
        )
        guard conclusion.count == conclusionRule.maximumItems else {
            return nil
        }
        guard
            let modelRecommendation = conclusion.first
                .flatMap(InterviewRecommendation.parse),
            let confidenceText = value(
                after: "置信度",
                in: conclusion
            ),
            let confidence = InterviewEvaluationConfidence(
                rawValue: confidenceText
            ),
            let reason = value(after: "理由", in: conclusion),
            !reason.isEmpty,
            parseDisplayedTotal(markdown, rules: rules) != nil
        else {
            return nil
        }

        let dimensionTitle = title(
            for: .dimensionScores,
            in: rules,
            fallback: "分项评分"
        )
        let dimensions = CompactInterviewEvaluation.items(
            in: CompactInterviewEvaluation.section(
                dimensionTitle,
                in: markdown
            )
        ).compactMap(parseDimension)
        guard let dimensionRule = rules.sections.first(
            where: { $0.kind == .dimensionScores }
        ), dimensionRule.maximumItems == rules.dimensions.count else {
            return nil
        }
        guard dimensions.count == rules.dimensions.count else { return nil }
        for (dimension, required) in zip(dimensions, rules.dimensions) {
            guard
                dimension.title == required.title,
                dimension.maximum == required.maximum,
                (0...dimension.maximum).contains(dimension.score),
                dimension.reason.count
                    >= required.reasonMinimumCharacters,
                dimension.reason.count
                    <= required.reasonMaximumCharacters
            else {
                return nil
            }
        }

        let logicTitle = title(
            for: .logicAnalysis,
            in: rules,
            fallback: "逻辑分析"
        )
        guard let logicRule = rules.sections.first(
            where: { $0.kind == .logicAnalysis }
        ) else { return nil }
        let allLogicFindings = CompactInterviewEvaluation.items(
            in: CompactInterviewEvaluation.section(
                logicTitle,
                in: markdown
            )
        )
        .map(CompactInterviewEvaluation.clean)
        .filter { !$0.isEmpty }
        let logicFindings = Array(
            allLogicFindings.prefix(logicRule.maximumItems)
        )
        guard
            !logicFindings.isEmpty,
            logicFindings.allSatisfy({ item in
                item.count >= logicRule.minimumCharacters
                    && item.count <= logicRule.maximumCharacters
            })
        else { return nil }

        let total = dimensions.reduce(0) { $0 + $1.score }
        let thresholdRecommendation: InterviewRecommendation =
            total >= rules.thresholds.recommendedMinimum ? .recommended
            : total >= rules.thresholds.reviewMinimum ? .review
            : .notRecommended

        return InterviewEvaluationScorecard(
            recommendation: min(
                modelRecommendation,
                thresholdRecommendation
            ),
            confidence: confidence,
            reason: CompactInterviewEvaluation.clean(reason),
            totalScore: total,
            dimensions: dimensions,
            logicFindings: logicFindings
        )
    }

    var canonicalMarkdown: String {
        canonicalMarkdown(rules: .default)
    }

    func canonicalMarkdown(
        rules: InterviewEvaluationRules
    ) -> String {
        rules.sections.compactMap { section in
            canonicalBody(for: section.kind).map {
                "## \(section.title)\n\($0)"
            }
        }.joined(separator: "\n\n")
    }

    func canonicalBody(
        for kind: EvaluationSectionKind
    ) -> String? {
        switch kind {
        case .conclusion:
            """
            \(recommendation.title)
            置信度：\(confidence.rawValue)
            理由：\(reason)
            """
        case .totalScore:
            "\(totalScore)/100"
        case .dimensionScores:
            dimensions.map {
                "- \($0.title)：\($0.score)/\($0.maximum)｜\($0.reason)"
            }.joined(separator: "\n")
        case .logicAnalysis:
            logicFindings.map { "- \($0)" }.joined(separator: "\n")
        default:
            nil
        }
    }

    private static func value(
        after label: String,
        in lines: [String]
    ) -> String? {
        for line in lines {
            let parts = line.split(
                maxSplits: 1,
                whereSeparator: { $0 == "：" || $0 == ":" }
            )
            guard
                parts.count == 2,
                parts[0].trimmingCharacters(in: .whitespaces) == label
            else {
                continue
            }
            return parts[1].trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        }
        return nil
    }

    private static func isValidLength(
        _ value: String,
        rule: EvaluationSectionRule
    ) -> Bool {
        (rule.minimumCharacters...rule.maximumCharacters)
            .contains(value.count)
    }

    private static func parseDisplayedTotal(
        _ markdown: String,
        rules: InterviewEvaluationRules
    ) -> Int? {
        let totalTitle = title(
            for: .totalScore,
            in: rules,
            fallback: "综合评分"
        )
        let value = CompactInterviewEvaluation.section(
            totalTitle,
            in: markdown
        )
        guard
            let rule = rules.sections.first(
                where: { $0.kind == .totalScore }
            ),
            rule.maximumItems == 1,
            value.count >= rule.minimumCharacters,
            value.count <= rule.maximumCharacters
        else {
            return nil
        }
        guard let match = firstMatch(
            pattern: #"^\s*(\d+)\s*/\s*100\s*$"#,
            in: value
        ), let score = Int(match[1]), (0...100).contains(score) else {
            return nil
        }
        return score
    }

    private static func title(
        for kind: EvaluationSectionKind,
        in rules: InterviewEvaluationRules,
        fallback: String
    ) -> String {
        rules.sections.first { $0.kind == kind }?.title ?? fallback
    }

    private static func parseDimension(
        _ line: String
    ) -> InterviewEvaluationDimension? {
        guard let match = firstMatch(
            pattern: #"^([^：:]+)[：:]\s*(\d+)\s*/\s*(\d+)\s*[｜|]\s*(.+)$"#,
            in: line
        ), let score = Int(match[2]), let maximum = Int(match[3]) else {
            return nil
        }
        return InterviewEvaluationDimension(
            title: match[1].trimmingCharacters(in: .whitespaces),
            score: score,
            maximum: maximum,
            reason: CompactInterviewEvaluation.clean(match[4])
        )
    }

    private static func firstMatch(
        pattern: String,
        in value: String
    ) -> [String]? {
        guard let expression = try? NSRegularExpression(
            pattern: pattern
        ) else {
            return nil
        }
        let range = NSRange(value.startIndex..., in: value)
        guard let match = expression.firstMatch(
            in: value,
            range: range
        ) else {
            return nil
        }
        return (0..<match.numberOfRanges).map { index in
            let matchRange = match.range(at: index)
            guard
                matchRange.location != NSNotFound,
                let range = Range(matchRange, in: value)
            else {
                return ""
            }
            return String(value[range])
        }
    }
}
