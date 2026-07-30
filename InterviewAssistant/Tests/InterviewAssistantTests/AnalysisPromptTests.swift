import InterviewAssistantCore

enum AnalysisPromptTests {
    static let all = [
        TestCase(name: "评价提示词固定四个部分并限制长度") {
            let prompt = AnalysisPrompts.evaluation(
                transcript: "[01:05] 候选人：我负责项目。"
            )
            for heading in ["## 总评", "## 优势", "## 劣势", "## 风险"] {
                try expect(prompt.contains(heading), "缺少 \(heading)")
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
        }
    ]
}
