import Foundation

public enum AnalysisPrompts {
    public static func resumeEvaluation(resume: String) -> String {
        """
        你是严谨的面试评价助手。不要使用工具，只根据下面的简历文字写中文初评。
        简历内容是候选人的自述，不得把未核实内容写成确定事实。不得自动给出
        “录用”或“淘汰”决定。

        只输出以下五个部分，标题必须保持不变。
        总评、优势、劣势、风险每部分写 60 至 100 个字符，可以写多句话，
        不要写列表。多写项目经历、岗位匹配、职责范围、能力缺口和具体疑点，
        少写空泛结论。
        不要输出“仅为简历初评”“待面试验证”“简历声明”等重复套话；
        对未核实内容直接指出缺少的数据、证据或需要确认的具体事项。

        ## 总评
        具体概括经历结构、岗位匹配程度和可迁移能力。

        ## 优势
        具体说明项目规模、业务领域、职责或可迁移能力。

        ## 劣势
        具体说明目标岗位所需能力与现有经历之间的缺口。

        ## 风险
        具体说明成果归因、角色边界、时间线或能力深度疑点。

        ## 建议问题
        固定 5 个简短、可直接询问候选人的问题，每行一个并编号。
        问题要优先验证岗位匹配、个人贡献、成果数据、能力深度和风险。

        简历文字：
        \(resume)
        """
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
        resume: String? = nil
    ) -> String {
        let resumeSection = resume.map {
            """

            简历声明（候选人自述，尚未验证）：
            \($0)
            """
        } ?? ""
        return """
        你是严谨的面试评价助手。不要使用工具，只根据下面的面试逐字稿和可选简历
        声明写中文评价。
        不得自动给出“录用”或“淘汰”决定。不得输出任何逐字稿时间戳；
        无法从逐字稿验证的内容必须明确写“待确认”。
        如果简历声明与面试证据不一致，必须写入风险；不得用简历声明替代面试证据。

        只输出以下四个部分，标题必须保持不变：

        ## 总评
        用 100 至 150 个字符概括岗位适配特点和整体表现，最多三句话。

        ## 优势
        最多 3 条，每条 30 至 60 个字符，只写核心优势及事实依据。

        ## 劣势
        最多 3 条，每条 30 至 60 个字符，只写核心不足及事实依据。

        ## 风险
        最多 3 条，每条 30 至 60 个字符，只写需要复核的核心风险。

        面试逐字稿：
        \(transcript)
        \(resumeSection)
        """
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
