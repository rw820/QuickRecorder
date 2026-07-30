import Foundation
import InterviewAssistantCore

enum IntelligenceModelTests {
    static let all = [
        TestCase(name: "转写行显示说话人和时间") {
            let line = TranscriptLine(
                source: .system,
                startTime: 65,
                endTime: 70,
                text: "我负责推荐项目。"
            )
            try expect(
                line.displayText == "[01:05] 候选人：我负责推荐项目。",
                "系统声音应该显示为候选人"
            )
        },
        TestCase(name: "评价必须包含四个主要部分") {
            let evaluation = InterviewEvaluation(
                markdown: """
                ## 总评
                A
                ## 优势
                B
                ## 劣势
                C
                ## 风险
                D
                """
            )
            try expect(
                evaluation.hasRequiredSections,
                "评价结构不完整"
            )
        },
        TestCase(name: "最终评价会移除时间戳并限制为三条") {
            let output = """
            ## 总评
            熟悉资金结算链路（[02:18]-[04:35]），可以独立负责成熟系统。

            ## 优势
            - 熟悉账户和流水模块（[02:18]-[04:35]、[12:13]-[12:49]）。
            - 能识别实际业务问题 [07:12]。
            - 具备跨系统协同经验。
            - 这是不应保留的第四条。

            ## 劣势
            - 量化意识不足（[13:25]-[14:00]）。

            ## 风险
            - 0到1经历与本次回答存在差异，[22:05] 待复核。
            """

            guard let evaluation = CompactInterviewEvaluation.normalize(output)
            else {
                throw TestFailure(description: "应成功清理完整评价")
            }
            try expect(
                !evaluation.markdown.contains("[02:18]")
                    && !evaluation.markdown.contains("[04:35]")
                    && !evaluation.markdown.contains("[12:13]")
                    && !evaluation.markdown.contains("[12:49]")
                    && !evaluation.markdown.contains("[07:12]")
                    && !evaluation.markdown.contains("[13:25]")
                    && !evaluation.markdown.contains("[14:00]")
                    && !evaluation.markdown.contains("[22:05]"),
                "评价中不应保留任何时间戳"
            )
            try expect(
                !evaluation.markdown.contains("（、）")
                    && !evaluation.markdown.contains("（）"),
                "删除时间戳后不应留下空括号"
            )
            let advantages = CompactInterviewEvaluation.items(
                in: CompactInterviewEvaluation.section(
                    "优势",
                    in: evaluation.markdown
                )
            )
            try expect(advantages.count == 3, "优势最多保留三条")
            try expect(
                !evaluation.markdown.contains("第四条"),
                "第四条不应保留"
            )
        },
        TestCase(name: "评分评价可以解析结论分数和逻辑问题") {
            let scorecard = try scoredEvaluation()
            try expect(
                scorecard.recommendation == .notRecommended,
                "58 分不能保留更积极的复核建议"
            )
            try expect(scorecard.confidence == .medium, "应解析中置信度")
            try expect(scorecard.totalScore == 58, "应解析综合评分")
            try expect(scorecard.dimensions.count == 5, "应解析五项分数")
            try expect(
                scorecard.logicFindings.count == 2,
                "应解析两条逻辑问题"
            )
        },
        TestCase(name: "评分总分以五项相加结果为准") {
            let markdown = scoredMarkdown()
                .replacingOccurrences(of: "58/100", with: "80/100")
            guard let scorecard = InterviewEvaluationScorecard.parse(
                from: markdown
            ) else {
                throw TestFailure(description: "应接受可修正的总分")
            }
            try expect(scorecard.totalScore == 58, "应重新计算总分")
        },
        TestCase(name: "评分不能超过分项上限") {
            let markdown = scoredMarkdown()
                .replacingOccurrences(
                    of: "逻辑表达：11/25",
                    with: "逻辑表达：26/25"
                )
            try expect(
                InterviewEvaluationScorecard.parse(from: markdown) == nil,
                "超出上限的分数应被拒绝"
            )
        },
        TestCase(name: "评分结构不完整时拒绝整份评价") {
            let markdown = scoredMarkdown()
                .replacingOccurrences(
                    of: "- 风险一致性：12/15｜职责边界存在差异。\n",
                    with: ""
                )
            try expect(
                CompactInterviewEvaluation.normalize(markdown) == nil,
                "评分评价必须包含五项完整分数"
            )
        },
        TestCase(name: "旧版四段评价仍可正常读取") {
            let markdown = """
            ## 总评
            具备相关场景经验。
            ## 优势
            - 能推动跨团队协作。
            ## 劣势
            - 量化证据不足。
            ## 风险
            - 职责边界待确认。
            """
            guard let evaluation = CompactInterviewEvaluation.normalize(
                markdown
            ) else {
                throw TestFailure(description: "旧版评价应保持兼容")
            }
            try expect(
                !evaluation.markdown.contains("## 综合评分"),
                "旧版评价不应生成虚构分数"
            )
        }
    ]

    private static func scoredEvaluation()
        throws -> InterviewEvaluationScorecard {
        guard let scorecard = InterviewEvaluationScorecard.parse(
            from: scoredMarkdown()
        ) else {
            throw TestFailure(description: "应成功解析完整评分评价")
        }
        return scorecard
    }

    private static func scoredMarkdown() -> String {
        """
        ## 结论
        保留复核
        置信度：中
        理由：回答结构与量化证据仍需复核。

        ## 综合评分
        58/100

        ## 分项评分
        - 逻辑表达：11/25｜多次回答未先给结论。
        - 岗位匹配：13/20｜具备财务数据场景经验。
        - 专业能力：12/20｜技术全链路说明不完整。
        - 成果证据：10/20｜量化结果不足。
        - 风险一致性：12/15｜职责边界存在差异。

        ## 逻辑分析
        - 答非所问：价值判断问题回答成既定任务描述。
        - 因果不完整：缺少行动后的量化结果。

        ## 总评
        能处理财务数据需求，但表达结构和证据仍显不足。

        ## 优势
        - 具备财务数据场景经验。

        ## 劣势
        - 回答缺少结论和完整因果。

        ## 风险
        - 简历与面试中的职责边界不一致。
        """
    }
}
