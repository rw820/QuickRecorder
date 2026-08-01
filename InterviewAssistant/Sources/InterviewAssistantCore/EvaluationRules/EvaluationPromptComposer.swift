import Foundation

public enum EvaluationPromptComposer {
    public static func interview(
        rules: InterviewEvaluationRules,
        transcript: String,
        resume: String? = nil,
        customRequirement: String? = nil
    ) -> String {
        let contract = interviewContract(rules)
        let requirement = cleaned(customRequirement)
        if rules.promptMode == .advanced {
            return replaceVariables(
                in: rules.advancedPromptTemplate,
                values: [
                    "{{outputContract}}": contract,
                    "{{customRequirement}}": requirement,
                    "{{transcript}}": transcript,
                    "{{resume}}": resume ?? ""
                ]
            )
        }

        let evidence = rules.evidenceRules.enumerated().map {
            "\($0.offset + 1). \($0.element)"
        }.joined(separator: "\n")
        let logic = rules.logicChecks.enumerated().map {
            "\($0.offset + 1). \($0.element)"
        }.joined(separator: "\n")
        let requirementSection = requirement.isEmpty ? "" : """

        本次刷新要求：
        \(requirement)
        在保持输出结构和事实约束的前提下，优先满足以上要求。
        """
        let resumeSection = resume.map {
            """

            简历声明（候选人自述，尚未验证）：
            \($0)
            """
        } ?? ""
        return """
        \(rules.baseInstruction)
        不要使用工具。结论只是给面试官的辅助建议，不是最终录用或淘汰决定。
        不得输出任何逐字稿时间戳；无法验证的内容必须明确写“待确认”。

        先按语义重建问题与回答，不要机械相信说话人标签。跨多轮回答检查：
        \(logic)
        只有相同结构问题在多个回答中重复出现，才能判定为逻辑表达不足。

        事实和公平约束：
        \(evidence)
        证据不足、逐字稿过短或关键问题未覆盖时，最高只能给“保留复核”。

        \(contract)
        \(requirementSection)
        面试逐字稿：
        \(transcript)
        \(resumeSection)
        """
    }

    public static func resume(
        rules: ResumeEvaluationRules,
        resume: String,
        customRequirement: String? = nil
    ) -> String {
        let contract = resumeContract(rules)
        let requirement = cleaned(customRequirement)
        if rules.promptMode == .advanced {
            return replaceVariables(
                in: rules.advancedPromptTemplate,
                values: [
                    "{{outputContract}}": contract,
                    "{{customRequirement}}": requirement,
                    "{{resume}}": resume,
                    "{{transcript}}": ""
                ]
            )
        }

        let principles = rules.principles.enumerated().map {
            "\($0.offset + 1). \($0.element)"
        }.joined(separator: "\n")
        let requirementSection = requirement.isEmpty ? "" : """

        本次刷新要求：
        \(requirement)
        在保持输出结构和事实约束的前提下，优先满足以上要求。
        """
        return """
        \(rules.baseInstruction)
        不要使用工具。不得自动给出“录用”或“淘汰”决定。

        评价原则：
        \(principles)
        不要输出“仅为简历初评”“待面试验证”“简历声明”等重复套话。

        \(contract)
        \(requirementSection)
        简历文字：
        \(resume)
        """
    }

    public static func preview(
        configuration: EvaluationRulesConfiguration,
        target: EvaluationRulesPreviewTarget
    ) -> String {
        switch target {
        case .interview:
            interview(
                rules: configuration.interview,
                transcript: "【面试逐字稿】",
                resume: "【可选简历】",
                customRequirement: "【本次刷新要求】"
            )
        case .resume:
            resume(
                rules: configuration.resume,
                resume: "【简历文字】",
                customRequirement: "【本次刷新要求】"
            )
        }
    }

    private static func interviewContract(
        _ rules: InterviewEvaluationRules
    ) -> String {
        let scoreLines = rules.dimensions.map {
            "- \($0.title)：数字/\($0.maximum)｜\($0.reasonMinimumCharacters) 至 \($0.reasonMaximumCharacters) 个字符的理由；评价重点：\($0.instruction)"
        }.joined(separator: "\n")
        let recommended = rules.thresholds.recommendedMinimum
        let review = rules.thresholds.reviewMinimum
        let recommendationRule = """
        满分 100 分，各项分数必须严格相加。
        \(recommended) 分及以上可给“建议通过”；\(review) 至 \(recommended - 1) 分最高给“保留复核”；\(review - 1) 分及以下最高给“不建议通过”。模型可以更谨慎，但不能更积极。
        """
        let sections = rules.sections.map { section in
            switch section.kind {
            case .conclusion:
                return """
                ## \(section.title)
                第一行只写：建议通过、保留复核或不建议通过。
                第二行写“置信度：高/中/低”。第三行写“理由：”和一句理由。
                \(section.instruction)，内容不超过 \(section.maximumCharacters) 个字符。
                """
            case .totalScore:
                return "## \(section.title)\n只写“数字/100”。\(section.instruction)。"
            case .dimensionScores:
                return "## \(section.title)\n\(section.instruction)。严格使用以下格式：\n\(scoreLines)"
            default:
                return sectionContract(section)
            }
        }.joined(separator: "\n\n")
        return """
        \(recommendationRule)

        只输出以下部分，标题和顺序必须保持不变：

        \(sections)
        """
    }

    private static func resumeContract(
        _ rules: ResumeEvaluationRules
    ) -> String {
        let sections = rules.sections.map { section in
            if section.kind == .questions {
                return """
                ## \(section.title)
                固定 \(rules.questionCount) 个简短、可直接询问候选人的问题，每行一个并编号。\(section.instruction)
                """
            }
            return sectionContract(section)
        }.joined(separator: "\n\n")
        return """
        只输出以下部分，标题和顺序必须保持不变：

        \(sections)
        """
    }

    private static func sectionContract(
        _ section: EvaluationSectionRule
    ) -> String {
        let itemRule = section.maximumItems == 1
            ? "不要写列表"
            : "最多 \(section.maximumItems) 条"
        return """
        ## \(section.title)
        \(section.instruction)。\(itemRule)，每条 \(section.minimumCharacters) 至 \(section.maximumCharacters) 个字符。
        """
    }

    private static func cleaned(_ value: String?) -> String {
        value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static func replaceVariables(
        in template: String,
        values: [String: String]
    ) -> String {
        values.reduce(template) { result, pair in
            result.replacingOccurrences(of: pair.key, with: pair.value)
        }
    }
}

public enum EvaluationRulesPreviewTarget: Hashable, Sendable {
    case interview
    case resume
}
