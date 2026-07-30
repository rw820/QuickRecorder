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
        let conclusion = CompactInterviewEvaluation.items(
            in: CompactInterviewEvaluation.section(
                "结论",
                in: markdown
            )
        )
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
            parseDisplayedTotal(markdown) != nil
        else {
            return nil
        }

        let dimensions = CompactInterviewEvaluation.items(
            in: CompactInterviewEvaluation.section(
                "分项评分",
                in: markdown
            )
        ).compactMap(parseDimension)
        let expected: [(String, Int)] = [
            ("逻辑表达", 25),
            ("岗位匹配", 20),
            ("专业能力", 20),
            ("成果证据", 20),
            ("风险一致性", 15)
        ]
        guard dimensions.count == expected.count else { return nil }
        for (dimension, required) in zip(dimensions, expected) {
            guard
                dimension.title == required.0,
                dimension.maximum == required.1,
                (0...dimension.maximum).contains(dimension.score),
                !dimension.reason.isEmpty
            else {
                return nil
            }
        }

        let logicFindings = CompactInterviewEvaluation.items(
            in: CompactInterviewEvaluation.section(
                "逻辑分析",
                in: markdown
            )
        )
        .map(CompactInterviewEvaluation.clean)
        .filter { !$0.isEmpty }
        guard !logicFindings.isEmpty else { return nil }

        let total = dimensions.reduce(0) { $0 + $1.score }
        let thresholdRecommendation: InterviewRecommendation =
            total >= 75 ? .recommended
            : total >= 60 ? .review
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
            logicFindings: Array(logicFindings.prefix(3))
        )
    }

    var canonicalMarkdown: String {
        let dimensionText = dimensions.map {
            "- \($0.title)：\($0.score)/\($0.maximum)｜\($0.reason)"
        }.joined(separator: "\n")
        let logicText = logicFindings.map { "- \($0)" }
            .joined(separator: "\n")
        return """
        ## 结论
        \(recommendation.title)
        置信度：\(confidence.rawValue)
        理由：\(reason)

        ## 综合评分
        \(totalScore)/100

        ## 分项评分
        \(dimensionText)

        ## 逻辑分析
        \(logicText)
        """
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

    private static func parseDisplayedTotal(
        _ markdown: String
    ) -> Int? {
        let value = CompactInterviewEvaluation.section(
            "综合评分",
            in: markdown
        )
        guard let match = firstMatch(
            pattern: #"^\s*(\d+)\s*/\s*100\s*$"#,
            in: value
        ), let score = Int(match[1]), (0...100).contains(score) else {
            return nil
        }
        return score
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
