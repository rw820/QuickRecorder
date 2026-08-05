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
        },
        TestCase(name: "自定义评分维度阈值和板块可以解析") {
            var rules = relaxedInterviewRules()
            rules.dimensions[0].title = "分析逻辑"
            rules.dimensions[0].maximum = 30
            rules.dimensions[1].maximum = 15
            rules.thresholds = DecisionThresholdRules(
                recommendedMinimum: 80,
                reviewMinimum: 65
            )
            rules.sections[4].title = "综合判断"
            rules.sections.append(
                EvaluationSectionRule(
                    id: "collaboration",
                    kind: .custom,
                    title: "协作表现",
                    instruction: "评价跨团队协作",
                    maximumItems: 2,
                    minimumCharacters: 5,
                    maximumCharacters: 60,
                    isRequired: true
                )
            )
            let markdown = scoredMarkdown()
                .replacingOccurrences(
                    of: "逻辑表达：11/25",
                    with: "分析逻辑：16/30"
                )
                .replacingOccurrences(
                    of: "岗位匹配：13/20",
                    with: "岗位匹配：8/15"
                )
                .replacingOccurrences(of: "## 总评", with: "## 综合判断")
                + "\n\n## 协作表现\n- 能推动财务与研发协作。"

            guard let evaluation = CompactInterviewEvaluation.normalize(
                markdown,
                rules: rules
            ), let scorecard = InterviewEvaluationScorecard.parse(
                from: evaluation.markdown,
                rules: rules
            ) else {
                throw TestFailure(description: "自定义评价应成功解析")
            }

            try expect(scorecard.totalScore == 58, "应按自定义维度求和")
            try expect(
                scorecard.recommendation == .notRecommended,
                "58分不应超过自定义复核线"
            )
            try expect(
                evaluation.markdown.contains("## 协作表现"),
                "应保留自定义输出板块"
            )
            var reordered = rules
            reordered.sections.swapAt(0, 4)
            guard let reorderedEvaluation =
                CompactInterviewEvaluation.normalize(
                    markdown,
                    rules: reordered
                )
            else {
                throw TestFailure(description: "重排评价应成功解析")
            }
            let summaryRange = reorderedEvaluation.markdown.range(
                of: "## 综合判断"
            )
            let conclusionRange = reorderedEvaluation.markdown.range(
                of: "## 结论"
            )
            try expect(
                summaryRange?.lowerBound ?? reorderedEvaluation.markdown.endIndex
                    < conclusionRange?.lowerBound
                        ?? reorderedEvaluation.markdown.endIndex,
                "保存结果应遵循配置的板块顺序"
            )
        },
        TestCase(name: "面试评价严格执行理由和板块长度") {
            var rules = EvaluationRulesConfiguration.default.interview
            rules.dimensions[0].reasonMinimumCharacters = 30
            try expect(
                CompactInterviewEvaluation.normalize(
                    scoredMarkdown(),
                    rules: rules
                ) == nil,
                "过短的评分理由不应被接受"
            )
            rules = relaxedInterviewRules()
            guard let summaryIndex = rules.sections.firstIndex(
                where: { $0.kind == .summary }
            ) else {
                throw TestFailure(description: "缺少总评规则")
            }
            rules.sections[summaryIndex].minimumCharacters = 80
            try expect(
                CompactInterviewEvaluation.normalize(
                    scoredMarkdown(),
                    rules: rules
                ) == nil,
                "过短的总评不应被接受"
            )
            rules = relaxedInterviewRules()
            guard let totalIndex = rules.sections.firstIndex(
                where: { $0.kind == .totalScore }
            ) else {
                throw TestFailure(description: "缺少综合评分规则")
            }
            rules.sections[totalIndex].maximumCharacters = 3
            try expect(
                CompactInterviewEvaluation.normalize(
                    scoredMarkdown(),
                    rules: rules
                ) == nil,
                "综合评分也应执行板块长度"
            )
        },
        TestCase(name: "逻辑分析条数跟随配置") {
            var rules = relaxedInterviewRules()
            guard let index = rules.sections.firstIndex(
                where: { $0.kind == .logicAnalysis }
            ) else {
                throw TestFailure(description: "缺少逻辑分析规则")
            }
            rules.sections[index].maximumItems = 1
            rules.sections[index].minimumCharacters = 1
            guard let evaluation = CompactInterviewEvaluation.normalize(
                scoredMarkdown(),
                rules: rules
            ) else {
                throw TestFailure(description: "应解析评价")
            }
            try expect(
                CompactInterviewEvaluation.items(
                    in: CompactInterviewEvaluation.section(
                        "逻辑分析",
                        in: evaluation.markdown
                    )
                ).count == 1,
                "逻辑分析应遵循最大条数"
            )
        },
        TestCase(name: "简历初评支持自定义标题和问题数量") {
            var rules = relaxedResumeRules()
            rules.questionCount = 3
            if let questionIndex = rules.sections.firstIndex(
                where: { $0.kind == .questions }
            ) {
                rules.sections[questionIndex].maximumItems = 3
            }
            rules.sections[0].title = "匹配判断"
            let output = """
            ## 匹配判断
            经历与岗位基本匹配。
            ## 优势
            财务产品经验较完整。
            ## 劣势
            技术深度信息不足。
            ## 风险
            成果归因需要确认。
            ## 建议问题
            1. 你的个人贡献是什么？
            2. 成果如何计算？
            3. 最大难点是什么？
            """

            guard let evaluation = CompactResumeEvaluation.normalize(
                output,
                rules: rules
            ) else {
                throw TestFailure(description: "自定义简历评价应解析")
            }
            try expect(
                evaluation.markdown.contains("## 匹配判断"),
                "应保留自定义标题"
            )
            try expect(
                CompactResumeEvaluation.questions(
                    in: evaluation.markdown,
                    heading: "建议问题"
                ).count == 3,
                "应保留配置的问题数量"
            )
        },
        TestCase(name: "简历初评接受简短但结构完整的内容") {
            var rules = EvaluationRulesConfiguration.default.resume
            let output = """
            ## 总评
            经历与岗位基本匹配。
            ## 优势
            有相关项目经验。
            ## 劣势
            量化成果较少。
            ## 风险
            个人贡献需确认。
            ## 建议问题
            1. 你的个人贡献是什么？
            2. 成果如何量化？
            3. 最大项目难点是什么？
            4. 如何安排需求优先级？
            5. 为什么选择这个岗位？
            """
            try expect(
                CompactResumeEvaluation.normalize(
                    output,
                    rules: rules
                ) != nil,
                "结构完整时不应仅因字数不足丢弃整份评价"
            )
            let missingSection = """
            ## 总评
            经历与岗位基本匹配。
            ## 建议问题
            1. 你的个人贡献是什么？
            2. 成果如何量化？
            3. 最大项目难点是什么？
            4. 如何安排需求优先级？
            5. 为什么选择这个岗位？
            """
            try expect(
                CompactResumeEvaluation.normalize(
                    missingSection,
                    rules: rules
                ) == nil,
                "配置中存在的评价板块缺失时应触发纠正"
            )
            rules = relaxedResumeRules()
            rules.questionCount = 5
            let questionIndex = rules.sections.firstIndex {
                $0.kind == .questions
            }!
            rules.sections[questionIndex].maximumItems = 2
            let fiveQuestions = """
            ## 总评
            具备相关经验。
            ## 建议问题
            1. 问题一是什么？
            2. 问题二是什么？
            3. 问题三是什么？
            4. 问题四是什么？
            5. 问题五是什么？
            """
            try expect(
                CompactResumeEvaluation.normalize(
                    fiveQuestions,
                    rules: rules
                ) == nil,
                "固定问题数与板块上限冲突时不应接受"
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

    private static func relaxedInterviewRules()
        -> InterviewEvaluationRules {
        var rules = EvaluationRulesConfiguration.default.interview
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

    private static func relaxedResumeRules() -> ResumeEvaluationRules {
        var rules = EvaluationRulesConfiguration.default.resume
        rules.sections = rules.sections.map { section in
            var changed = section
            changed.minimumCharacters = 1
            return changed
        }
        return rules
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
