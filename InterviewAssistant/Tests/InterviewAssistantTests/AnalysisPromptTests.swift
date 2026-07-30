import InterviewAssistantCore

enum AnalysisPromptTests {
    static let all = [
        TestCase(name: "评价提示词要求评分结论和逻辑分析") {
            let prompt = AnalysisPrompts.evaluation(
                transcript: "[01:05] 候选人：我负责项目。"
            )
            for heading in [
                "## 结论", "## 综合评分", "## 分项评分", "## 逻辑分析",
                "## 总评", "## 优势", "## 劣势", "## 风险"
            ] {
                try expect(prompt.contains(heading), "缺少 \(heading)")
            }
            for score in [
                "逻辑表达：数字/25", "岗位匹配：数字/20",
                "专业能力：数字/20", "成果证据：数字/20",
                "风险一致性：数字/15"
            ] {
                try expect(prompt.contains(score), "缺少评分规则 \(score)")
            }
            for recommendation in [
                "建议通过", "保留复核", "不建议通过"
            ] {
                try expect(
                    prompt.contains(recommendation),
                    "缺少结论 \(recommendation)"
                )
            }
            try expect(
                prompt.contains("不得输出任何逐字稿时间戳"),
                "必须禁止输出时间戳"
            )
            try expect(
                prompt.contains("100 至 150 个字符"),
                "总评必须限制长度"
            )
            try expect(
                prompt.contains("最多 3 条")
                    && prompt.contains("30 至 60 个字符"),
                "列表部分必须限制条数和长度"
            )
            try expect(prompt.contains("待确认"), "证据不足必须待确认")
        },
        TestCase(name: "评价提示词深入检查回答逻辑并排除识别噪声") {
            let prompt = AnalysisPrompts.evaluation(
                transcript: "候选人回答"
            )
            for check in [
                "答非所问", "结构", "因果", "具体", "前后一致",
                "证据"
            ] {
                try expect(
                    prompt.contains(check),
                    "缺少逻辑检查：\(check)"
                )
            }
            try expect(
                prompt.contains("语义重建问题与回答")
                    && prompt.contains("不要机械相信说话人标签"),
                "应按语义重建问答关系"
            )
            try expect(
                prompt.contains("ASR")
                    && prompt.contains("口头语")
                    && prompt.contains("不得直接扣分"),
                "识别错误和偶发口头语不应直接扣分"
            )
            try expect(
                prompt.contains("证据不足")
                    && prompt.contains("最高只能给“保留复核”"),
                "证据不足时必须限制结论"
            )
            for excluded in [
                "年龄", "性别", "婚育", "籍贯"
            ] {
                try expect(
                    prompt.contains(excluded),
                    "必须排除岗位无关信息：\(excluded)"
                )
            }
        },
        TestCase(name: "建议提示词限制为三条") {
            let prompt = AnalysisPrompts.suggestions(
                transcript: "[01:05] 候选人：项目提升了转化率。"
            )
            try expect(prompt.contains("最多 3 条"), "建议不应超过三条")
            try expect(prompt.contains("问题："), "应固定问题格式")
            try expect(prompt.contains("依据："), "应要求逐字稿依据")
        },
        TestCase(name: "建议文本可以解析") {
            let text = """
            问题：这个指标的基线是多少？
            原因：确认结果是否可靠。
            依据：[01:05] 候选人提到转化率提升。

            问题：你个人负责了哪一部分？
            原因：区分团队与个人贡献。
            依据：[02:10] 候选人使用了“我们”。
            """
            let suggestions = CodexCLIProvider.parseSuggestions(text)
            try expect(suggestions.count == 2, "应解析出两条建议")
            try expect(
                suggestions.first?.question == "这个指标的基线是多少？",
                "问题内容解析错误"
            )
        },
        TestCase(name: "简历初评要求具体内容并禁用套话") {
            let prompt = AnalysisPrompts.resumeEvaluation(
                resume: "候选人自述：负责推荐项目。"
            )
            for heading in [
                "## 总评", "## 优势", "## 劣势", "## 风险",
                "## 建议问题"
            ] {
                try expect(prompt.contains(heading), "缺少 \(heading)")
            }
            try expect(
                prompt.contains("60 至 100 个字符"),
                "四项评价必须使用新的字数范围"
            )
            try expect(
                prompt.contains("固定 5 个"),
                "必须固定生成五个问题"
            )
            try expect(
                prompt.contains("不要输出")
                    && prompt.contains("仅为简历初评")
                    && prompt.contains("待面试验证")
                    && prompt.contains("简历声明"),
                "必须明确禁用重复套话"
            )
            try expect(
                prompt.contains("录用") && prompt.contains("淘汰"),
                "不能自动做录用决定"
            )
        },
        TestCase(name: "简历初评会限制长度并保留五个问题") {
            let longText = String(repeating: "复杂项目经验丰富", count: 20)
            let output = """
            ## 总评
            仅为简历初评，\(longText)，待面试验证。

            ## 优势
            - 简历声明：\(longText)

            ## 劣势
            \(longText)

            ## 风险
            \(longText)

            ## 建议问题
            1. 你在项目中的具体贡献是什么？
            2. 这个结果如何量化？
            3. 最大的项目难点是什么？
            4. 为什么转向产品经理？
            5. 如何处理需求优先级？
            6. 这是不应保留的第六题吗？
            """

            guard let result = CompactResumeEvaluation.normalize(output)
            else {
                throw TestFailure(description: "应成功格式化简历初评")
            }
            for heading in ["总评", "优势", "劣势", "风险"] {
                let text = CompactResumeEvaluation.section(
                    heading,
                    in: result.markdown
                )
                try expect(
                    text.count <= 100,
                    "\(heading)超过 100 个字符"
                )
                try expect(
                    !text.contains("仅为简历初评")
                        && !text.contains("待面试验证")
                        && !text.contains("简历声明"),
                    "\(heading)仍包含重复套话"
                )
            }
            let questions = CompactResumeEvaluation.questions(
                in: result.markdown
            )
            try expect(questions.count == 5, "应只保留五个问题")
        },
        TestCase(name: "联合评价同时包含简历和逐字稿") {
            let prompt = AnalysisPrompts.evaluation(
                transcript: "[01:05] 候选人：项目由团队完成。",
                resume: "简历写本人主导项目。"
            )
            try expect(prompt.contains("简历声明"), "缺少简历上下文")
            try expect(prompt.contains("面试逐字稿"), "缺少面试证据")
            try expect(prompt.contains("不一致"), "应检查信息冲突")
        },
        TestCase(name: "刷新要求会加入简历和面试评价提示词") {
            let resumePrompt = AnalysisPrompts.resumeEvaluation(
                resume: "候选人简历",
                customRequirement: "重点评价数据能力"
            )
            let interviewPrompt = AnalysisPrompts.evaluation(
                transcript: "候选人回答",
                customRequirement: "总评控制在八十字"
            )

            try expect(
                resumePrompt.contains("本次刷新要求")
                    && resumePrompt.contains("重点评价数据能力"),
                "简历评价应包含手工要求"
            )
            try expect(
                interviewPrompt.contains("本次刷新要求")
                    && interviewPrompt.contains("总评控制在八十字"),
                "面试评价应包含手工要求"
            )
        },
        TestCase(name: "空白刷新要求不会加入提示词") {
            let prompt = AnalysisPrompts.evaluation(
                transcript: "候选人回答",
                customRequirement: "   \n "
            )

            try expect(
                !prompt.contains("本次刷新要求"),
                "空白要求应按默认规则刷新"
            )
        }
    ]
}
