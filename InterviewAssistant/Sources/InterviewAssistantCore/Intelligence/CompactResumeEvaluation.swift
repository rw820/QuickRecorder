import Foundation

public enum CompactResumeEvaluation {
    private static let evaluationHeadings = [
        "总评", "优势", "劣势", "风险"
    ]

    public static func normalize(
        _ markdown: String
    ) -> InterviewEvaluation? {
        var rules = ResumeEvaluationRules.default
        rules.sections = rules.sections.map { section in
            var changed = section
            changed.minimumCharacters = 1
            return changed
        }
        return normalize(markdown, rules: rules)
    }

    public static func normalize(
        _ markdown: String,
        rules: ResumeEvaluationRules
    ) -> InterviewEvaluation? {
        var output: [String] = []
        for configured in rules.sections {
            if configured.kind == .questions {
                guard configured.maximumItems == rules.questionCount else {
                    return nil
                }
                let suggested = questions(
                    in: markdown,
                    heading: configured.title
                )
                guard suggested.count >= rules.questionCount else {
                    return nil
                }
                let retained = Array(suggested.prefix(rules.questionCount))
                guard retained.allSatisfy({
                    $0.count >= configured.minimumCharacters
                }) else {
                    return nil
                }
                let text = retained
                    .enumerated()
                    .map {
                        "\($0.offset + 1). \(limited($0.element, to: configured.maximumCharacters))"
                    }
                    .joined(separator: "\n")
                output.append("## \(configured.title)\n\(text)")
                continue
            }
            let cleaned = compact(
                section(configured.title, in: markdown)
            )
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
            output.append("## \(configured.title)\n\(value)")
        }
        guard !output.isEmpty else { return nil }
        return InterviewEvaluation(markdown: output.joined(separator: "\n\n"))
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

    public static func questions(
        in markdown: String,
        heading: String = "建议问题"
    ) -> [String] {
        section(heading, in: markdown)
            .components(separatedBy: .newlines)
            .map(cleanListPrefix)
            .filter { !$0.isEmpty }
    }

    private static func compact(
        _ text: String
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
        return joined
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
