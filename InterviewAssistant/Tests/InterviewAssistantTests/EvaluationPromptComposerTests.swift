import InterviewAssistantCore

enum EvaluationPromptComposerTests {
    static let all = [
        TestCase(name: "面试提示词使用可编辑评分阈值和板块") {
            var rules = EvaluationRulesConfiguration.default.interview
            rules.dimensions[0].title = "分析逻辑"
            rules.dimensions[0].maximum = 30
            rules.dimensions[1].maximum = 15
            rules.thresholds = DecisionThresholdRules(
                recommendedMinimum: 80,
                reviewMinimum: 65
            )
            rules.sections.append(
                EvaluationSectionRule(
                    id: "culture",
                    kind: .custom,
                    title: "协作表现",
                    instruction: "评价跨团队协作",
                    maximumItems: 2,
                    minimumCharacters: 10,
                    maximumCharacters: 50,
                    isRequired: false
                )
            )

            let prompt = EvaluationPromptComposer.interview(
                rules: rules,
                transcript: "候选人：我负责项目。",
                resume: "候选人简历",
                customRequirement: "重点关注协作"
            )

            for value in [
                "分析逻辑：数字/30",
                "20 至 60 个字符",
                "检查回答是否直接",
                "岗位匹配：数字/15",
                "80 分及以上",
                "65 至 79 分",
                "## 协作表现",
                "重点关注协作",
                "候选人：我负责项目。",
                "候选人简历"
            ] {
                try expect(prompt.contains(value), "提示词缺少\(value)")
            }
            rules.sections[0].instruction = "先给明确结论"
            let changedContract = EvaluationPromptComposer.interview(
                rules: rules,
                transcript: "回答"
            )
            try expect(
                changedContract.contains("先给明确结论"),
                "必需板块说明应影响提示词"
            )
        },
        TestCase(name: "简历提示词使用板块顺序和问题数量") {
            var rules = EvaluationRulesConfiguration.default.resume
            rules.questionCount = 3
            rules.sections.swapAt(0, 1)

            let prompt = EvaluationPromptComposer.resume(
                rules: rules,
                resume: "产品经理简历",
                customRequirement: nil
            )

            let strengthRange = prompt.range(of: "## 优势")
            let summaryRange = prompt.range(of: "## 总评")
            try expect(
                strengthRange?.lowerBound ?? prompt.endIndex
                    < summaryRange?.lowerBound ?? prompt.endIndex,
                "输出合同应保留配置顺序"
            )
            try expect(prompt.contains("固定 3 个"), "应生成3个问题")
        },
        TestCase(name: "高级提示词替换所有模板变量") {
            var rules = EvaluationRulesConfiguration.default.interview
            rules.promptMode = .advanced
            rules.advancedPromptTemplate = """
            自定义开头
            {{outputContract}}
            要求={{customRequirement}}
            逐字稿={{transcript}}
            简历={{resume}}
            """

            let prompt = EvaluationPromptComposer.interview(
                rules: rules,
                transcript: "回答内容",
                resume: "简历内容",
                customRequirement: "关注逻辑"
            )

            for value in [
                "自定义开头", "## 结论", "要求=关注逻辑",
                "逐字稿=回答内容", "简历=简历内容"
            ] {
                try expect(prompt.contains(value), "高级提示词缺少\(value)")
            }
            try expect(!prompt.contains("{{"), "模板变量应全部替换")
        }
    ]
}
