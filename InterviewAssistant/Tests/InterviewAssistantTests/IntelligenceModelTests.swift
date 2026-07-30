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
        }
    ]
}
