import Foundation

public enum CompactResumeEvaluation {
    private static let evaluationHeadings = [
        "总评", "优势", "劣势", "风险"
    ]

    public static func normalize(
        _ markdown: String
    ) -> InterviewEvaluation? {
        var sections: [String: String] = [:]
        for heading in evaluationHeadings {
            let value = compact(section(heading, in: markdown), limit: 100)
            guard !value.isEmpty else { return nil }
            sections[heading] = value
        }

        let suggestedQuestions = questions(in: markdown)
        guard suggestedQuestions.count >= 5 else { return nil }
        let questionText = suggestedQuestions.prefix(5)
            .enumerated()
            .map { "\($0.offset + 1). \($0.element)" }
            .joined(separator: "\n")

        let output = evaluationHeadings.map {
            "## \($0)\n\(sections[$0] ?? "")"
        }
        .joined(separator: "\n\n")

        return InterviewEvaluation(
            markdown: "\(output)\n\n## 建议问题\n\(questionText)"
        )
    }

    public static func section(
        _ heading: String,
        in markdown: String
    ) -> String {
        let lines = markdown.components(separatedBy: .newlines)
        guard let start = lines.firstIndex(
            where: { $0.trimmingCharacters(in: .whitespaces) == "## \(heading)" }
        ) else {
            return ""
        }
        let body = lines.dropFirst(start + 1).prefix {
            !$0.trimmingCharacters(in: .whitespaces).hasPrefix("## ")
        }
        return body.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func questions(in markdown: String) -> [String] {
        section("建议问题", in: markdown)
            .components(separatedBy: .newlines)
            .map(cleanListPrefix)
            .filter { !$0.isEmpty }
    }

    private static func compact(
        _ text: String,
        limit: Int
    ) -> String {
        var joined = text.components(separatedBy: .newlines)
            .map(cleanListPrefix)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .replacingOccurrences(
                of: #"\s+"#,
                with: " ",
                options: .regularExpression
            )
        for phrase in [
            "仅为简历初评", "待面试验证", "简历声明"
        ] {
            joined = joined.replacingOccurrences(of: phrase, with: "")
        }
        joined = joined
            .replacingOccurrences(of: "，。", with: "。")
            .replacingOccurrences(of: "，,", with: "，")
            .replacingOccurrences(
                of: #"^[，。；：、,\s]+|[，；：、,\s]+$"#,
                with: "",
                options: .regularExpression
            )
        guard joined.count > limit else { return joined }
        return String(joined.prefix(limit - 1)) + "…"
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
