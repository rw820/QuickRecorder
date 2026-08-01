import Foundation

public enum CompactInterviewEvaluation {
    private static let listHeadings = ["优势", "劣势", "风险"]
    private static let scoreHeadings = [
        "结论", "综合评分", "分项评分", "逻辑分析"
    ]

    public static func normalize(
        _ markdown: String
    ) -> InterviewEvaluation? {
        normalize(markdown, rules: legacyCompatibleRules)
    }

    static var legacyCompatibleRules: InterviewEvaluationRules {
        var rules = InterviewEvaluationRules.default
        rules.dimensions = rules.dimensions.map { dimension in
            var changed = dimension
            changed.reasonMinimumCharacters = 1
            return changed
        }
        rules.sections = rules.sections.map { section in
            var changed = section
            changed.minimumCharacters = 1
            return changed
        }
        return rules
    }

    public static func normalize(
        _ markdown: String,
        rules: InterviewEvaluationRules
    ) -> InterviewEvaluation? {
        let configuredScoreHeadings = rules.sections.filter {
            [.conclusion, .totalScore, .dimensionScores, .logicAnalysis]
                .contains($0.kind)
        }.map(\.title)
        let headings = configuredScoreHeadings.isEmpty
            ? scoreHeadings
            : configuredScoreHeadings
        let hasScoreSection = headings.contains {
            !section($0, in: markdown).isEmpty
        }
        let scorecard: InterviewEvaluationScorecard?
        if hasScoreSection {
            guard let parsed = InterviewEvaluationScorecard.parse(
                from: markdown,
                rules: rules
            ) else {
                return nil
            }
            scorecard = parsed
        } else {
            scorecard = nil
        }

        var normalizedBodies: [String: String] = [:]
        let contentSections = rules.sections.filter {
            ![.conclusion, .totalScore, .dimensionScores, .logicAnalysis]
                .contains($0.kind)
        }
        for configured in contentSections {
            let raw = section(configured.title, in: markdown)
            if configured.maximumItems == 1 {
                let cleaned = clean(raw)
                if cleaned.isEmpty {
                    guard !configured.isRequired else { return nil }
                    continue
                }
                guard cleaned.count >= configured.minimumCharacters else {
                    return nil
                }
                let value = limited(
                    cleaned,
                    to: configured.maximumCharacters
                )
                normalizedBodies[configured.id] = value
                continue
            }
            let values = items(in: raw)
                .map(clean)
                .filter { !$0.isEmpty }
            if values.isEmpty {
                guard !configured.isRequired else { return nil }
                continue
            }
            let retained = Array(values.prefix(configured.maximumItems))
            guard retained.allSatisfy({
                $0.count >= configured.minimumCharacters
            }) else {
                return nil
            }
            let body = retained
                .map {
                    "- \(limited($0, to: configured.maximumCharacters))"
                }
                .joined(separator: "\n")
            normalizedBodies[configured.id] = body
        }
        guard !normalizedBodies.isEmpty else { return nil }
        let normalizedSections: [String] = rules.sections.compactMap {
            configured -> String? in
            let body = scorecard?.canonicalBody(for: configured.kind)
                ?? normalizedBodies[configured.id]
            guard let body, !body.isEmpty else { return nil }
            return "## \(configured.title)\n\(body)"
        }
        return InterviewEvaluation(
            markdown: normalizedSections.joined(separator: "\n\n")
        )
    }

    public static func section(
        _ heading: String,
        in markdown: String
    ) -> String {
        let lines = markdown.components(separatedBy: .newlines)
        guard let start = lines.firstIndex(
            where: {
                $0.trimmingCharacters(in: .whitespaces) == "## \(heading)"
            }
        ) else {
            return ""
        }
        let body = lines.dropFirst(start + 1).prefix {
            !$0.trimmingCharacters(in: .whitespaces).hasPrefix("## ")
        }
        return body.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func items(in text: String) -> [String] {
        text.components(separatedBy: .newlines)
            .map(cleanListPrefix)
            .filter { !$0.isEmpty }
    }

    static func clean(_ text: String) -> String {
        var value = text.replacingOccurrences(
            of: #"\[\d{1,2}:\d{2}(?::\d{2})?\]\s*[-–—~至到]\s*\[\d{1,2}:\d{2}(?::\d{2})?\]"#,
            with: "",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: #"\[\d{1,2}:\d{2}(?::\d{2})?\]"#,
            with: "",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: #"（[\s、，,；;]*）|\([\s、，,；;]*\)"#,
            with: "",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        )
        for pair in [
            "、。", "，。", ",。", "；。", ";。",
            "、，", "，，", ",，", "；，", ";，"
        ] {
            value = value.replacingOccurrences(
                of: pair,
                with: String(pair.last ?? " ")
            )
        }
        return value.replacingOccurrences(
            of: #"^[\s、，,；;]+|[\s、，,；;]+$"#,
            with: "",
            options: .regularExpression
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func limited(_ text: String, to limit: Int) -> String {
        guard text.count > limit, limit > 1 else { return text }
        return String(text.prefix(limit - 1)) + "…"
    }

    private static func cleanListPrefix(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(
                of: #"^(?:[-*•]\s*|\d+[.、)]\s*)"#,
                with: "",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespaces)
    }
}
