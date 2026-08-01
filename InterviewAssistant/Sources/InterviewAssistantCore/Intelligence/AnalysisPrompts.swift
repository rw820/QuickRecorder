import Foundation

public enum AnalysisPrompts {
    public static func resumeEvaluation(
        resume: String,
        customRequirement: String? = nil,
        rules: ResumeEvaluationRules = .default
    ) -> String {
        EvaluationPromptComposer.resume(
            rules: rules,
            resume: resume,
            customRequirement: customRequirement
        )
    }

    public static func suggestions(
        transcript: String,
        resume: String? = nil
    ) -> String {
        let resumeSection = resume.map {
            """

            简历声明（尚未验证）：
            \($0)
            """
        } ?? ""
        return """
        你是面试官的实时辅助工具。不要使用工具，不要补充材料里没有的事实。
        根据下面的面试逐字稿，给出现在最值得追问的建议，最多 3 条。
        优先发现：个人贡献不清、指标不可验证、关键细节缺失、前后矛盾，以及简历
        声明与面试回答之间的不一致。
        如果当前信息不足以形成有价值的追问，只输出“暂无建议”。

        每条必须严格使用三行，条目之间空一行，不要写前言或总结：
        问题：一句可以直接问候选人的问题
        原因：为什么现在值得问
        依据：对应的逐字稿时间戳、简历声明或简短原话

        面试逐字稿：
        \(transcript)
        \(resumeSection)
        """
    }

    public static func evaluation(
        transcript: String,
        resume: String? = nil,
        customRequirement: String? = nil,
        rules: InterviewEvaluationRules = .default
    ) -> String {
        EvaluationPromptComposer.interview(
            rules: rules,
            transcript: transcript,
            resume: resume,
            customRequirement: customRequirement
        )
    }

    public static func transcriptText(
        _ lines: [TranscriptLine],
        maximumCharacters: Int? = nil
    ) -> String {
        let text = lines
            .sorted {
                if $0.startTime == $1.startTime {
                    return $0.source.rawValue < $1.source.rawValue
                }
                return $0.startTime < $1.startTime
            }
            .map(\.displayText)
            .joined(separator: "\n")

        guard
            let maximumCharacters,
            text.count > maximumCharacters
        else {
            return text
        }
        return "（以下为最近一段逐字稿）\n"
            + String(text.suffix(maximumCharacters))
    }

}
