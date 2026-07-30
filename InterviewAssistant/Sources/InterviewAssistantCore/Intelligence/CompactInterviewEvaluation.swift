import Foundation

public enum CompactInterviewEvaluation {
    private static let listHeadings = ["优势", "劣势", "风险"]
    private static let scoreHeadings = [
        "结论", "综合评分", "分项评分", "逻辑分析"
    ]

    public static func normalize(
        _ markdown: String
    ) -> InterviewEvaluation? {
        let hasScoreSection = scoreHeadings.contains {
            !section($0, in: markdown).isEmpty
        }
        let scorecard: InterviewEvaluationScorecard?
        if hasScoreSection {
            guard let parsed = InterviewEvaluationScorecard.parse(
                from: markdown
            ) else {
                return nil
            }
            scorecard = parsed
        } else {
            scorecard = nil
        }

        let summary = clean(section("总评", in: markdown))
        guard !summary.isEmpty else { return nil }

        var normalizedSections: [String] = []
        for heading in listHeadings {
            let values = items(in: section(heading, in: markdown))
                .map(clean)
                .filter { !$0.isEmpty }
            guard !values.isEmpty else { return nil }
            let body = values.prefix(3)
                .map { "- \($0)" }
                .joined(separator: "\n")
            normalizedSections.append("## \(heading)\n\(body)")
        }

        let legacyMarkdown = """
            ## 总评
            \(summary)

            \(normalizedSections.joined(separator: "\n\n"))
            """
        return InterviewEvaluation(
            markdown: scorecard.map {
                "\($0.canonicalMarkdown)\n\n\(legacyMarkdown)"
            } ?? legacyMarkdown
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
