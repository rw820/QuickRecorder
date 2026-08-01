import Foundation

public enum PromptEditingMode: String, Codable, Sendable, CaseIterable {
    case structured
    case advanced
}

public struct ScoreDimensionRule: Codable, Equatable, Sendable,
    Identifiable
{
    public var id: String
    public var title: String
    public var maximum: Int
    public var instruction: String
    public var reasonMinimumCharacters: Int
    public var reasonMaximumCharacters: Int

    public init(
        id: String,
        title: String,
        maximum: Int,
        instruction: String,
        reasonMinimumCharacters: Int = 20,
        reasonMaximumCharacters: Int = 60
    ) {
        self.id = id
        self.title = title
        self.maximum = maximum
        self.instruction = instruction
        self.reasonMinimumCharacters = reasonMinimumCharacters
        self.reasonMaximumCharacters = reasonMaximumCharacters
    }
}

public struct DecisionThresholdRules: Codable, Equatable, Sendable {
    public var recommendedMinimum: Int
    public var reviewMinimum: Int

    public init(
        recommendedMinimum: Int,
        reviewMinimum: Int
    ) {
        self.recommendedMinimum = recommendedMinimum
        self.reviewMinimum = reviewMinimum
    }
}

public enum EvaluationSectionKind: String, Codable, Sendable,
    CaseIterable
{
    case conclusion
    case totalScore
    case dimensionScores
    case logicAnalysis
    case summary
    case strengths
    case weaknesses
    case risks
    case questions
    case custom
}

public struct EvaluationSectionRule: Codable, Equatable, Sendable,
    Identifiable
{
    public var id: String
    public var kind: EvaluationSectionKind
    public var title: String
    public var instruction: String
    public var maximumItems: Int
    public var minimumCharacters: Int
    public var maximumCharacters: Int
    public var isRequired: Bool

    public init(
        id: String,
        kind: EvaluationSectionKind,
        title: String,
        instruction: String,
        maximumItems: Int,
        minimumCharacters: Int,
        maximumCharacters: Int,
        isRequired: Bool
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.instruction = instruction
        self.maximumItems = maximumItems
        self.minimumCharacters = minimumCharacters
        self.maximumCharacters = maximumCharacters
        self.isRequired = isRequired
    }
}

public struct InterviewEvaluationRules: Codable, Equatable, Sendable {
    public var promptMode: PromptEditingMode
    public var baseInstruction: String
    public var evidenceRules: [String]
    public var logicChecks: [String]
    public var dimensions: [ScoreDimensionRule]
    public var thresholds: DecisionThresholdRules
    public var sections: [EvaluationSectionRule]
    public var advancedPromptTemplate: String

    public init(
        promptMode: PromptEditingMode,
        baseInstruction: String,
        evidenceRules: [String],
        logicChecks: [String],
        dimensions: [ScoreDimensionRule],
        thresholds: DecisionThresholdRules,
        sections: [EvaluationSectionRule],
        advancedPromptTemplate: String
    ) {
        self.promptMode = promptMode
        self.baseInstruction = baseInstruction
        self.evidenceRules = evidenceRules
        self.logicChecks = logicChecks
        self.dimensions = dimensions
        self.thresholds = thresholds
        self.sections = sections
        self.advancedPromptTemplate = advancedPromptTemplate
    }
}

public struct ResumeEvaluationRules: Codable, Equatable, Sendable {
    public var promptMode: PromptEditingMode
    public var baseInstruction: String
    public var principles: [String]
    public var sections: [EvaluationSectionRule]
    public var questionCount: Int
    public var advancedPromptTemplate: String

    public init(
        promptMode: PromptEditingMode,
        baseInstruction: String,
        principles: [String],
        sections: [EvaluationSectionRule],
        questionCount: Int,
        advancedPromptTemplate: String
    ) {
        self.promptMode = promptMode
        self.baseInstruction = baseInstruction
        self.principles = principles
        self.sections = sections
        self.questionCount = questionCount
        self.advancedPromptTemplate = advancedPromptTemplate
    }
}

public struct EvaluationRulesConfiguration: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var interview: InterviewEvaluationRules
    public var resume: ResumeEvaluationRules

    public init(
        schemaVersion: Int = 1,
        interview: InterviewEvaluationRules,
        resume: ResumeEvaluationRules
    ) {
        self.schemaVersion = schemaVersion
        self.interview = interview
        self.resume = resume
    }

    public static let `default` = EvaluationRulesConfiguration(
        interview: .default,
        resume: .default
    )
}

public extension InterviewEvaluationRules {
    static let `default` = InterviewEvaluationRules(
        promptMode: .structured,
        baseInstruction: "你是严谨的面试评价助手，只根据面试逐字稿和可选简历写中文评价。",
        evidenceRules: [
            "不得输出逐字稿时间戳，无法验证的内容必须写待确认",
            "简历与面试不一致时写入风险，不得用简历替代面试证据",
            "不得使用年龄、性别、婚育、籍贯等岗位无关信息评分",
            "ASR错误、孤立口头语和偶发重复不得直接扣分"
        ],
        logicChecks: [
            "答非所问：是否直接回答问题",
            "结构完整：是否先给结论，再说明背景、行动和结果",
            "因果闭环：问题、判断、行动与结果是否连贯",
            "具体程度：是否说明本人动作、对象、口径和细节",
            "前后一致：不同回答及简历是否存在事实冲突",
            "证据充分：是否有数据、样本、上线结果或可核实产出"
        ],
        dimensions: [
            ScoreDimensionRule(
                id: "logic",
                title: "逻辑表达",
                maximum: 25,
                instruction: "检查回答是否直接、结构完整且因果闭环"
            ),
            ScoreDimensionRule(
                id: "fit",
                title: "岗位匹配",
                maximum: 20,
                instruction: "检查经历和目标岗位的相关性"
            ),
            ScoreDimensionRule(
                id: "professional",
                title: "专业能力",
                maximum: 20,
                instruction: "检查专业深度和解决复杂问题的能力"
            ),
            ScoreDimensionRule(
                id: "evidence",
                title: "成果证据",
                maximum: 20,
                instruction: "检查个人贡献、量化结果和可核实产出"
            ),
            ScoreDimensionRule(
                id: "consistency",
                title: "风险一致性",
                maximum: 15,
                instruction: "检查职责边界、时间线和信息一致性"
            )
        ],
        thresholds: DecisionThresholdRules(
            recommendedMinimum: 75,
            reviewMinimum: 60
        ),
        sections: .defaultInterviewSections,
        advancedPromptTemplate: """
        你是严谨的面试评价助手。请根据材料输出评价。
        {{outputContract}}

        本次要求：
        {{customRequirement}}

        面试逐字稿：
        {{transcript}}

        简历：
        {{resume}}
        """
    )
}

public extension ResumeEvaluationRules {
    static let `default` = ResumeEvaluationRules(
        promptMode: .structured,
        baseInstruction: "你是严谨的面试评价助手，只根据简历文字写中文初评。",
        principles: [
            "简历内容是候选人自述，不得写成已核实事实",
            "不要自动给出录用或淘汰决定",
            "避免仅为简历初评、待面试验证、简历声明等套话",
            "优先写项目经历、岗位匹配、职责范围、能力缺口和具体疑点"
        ],
        sections: .defaultResumeSections,
        questionCount: 5,
        advancedPromptTemplate: """
        你是严谨的面试评价助手。请根据简历输出初评。
        {{outputContract}}

        本次要求：
        {{customRequirement}}

        简历文字：
        {{resume}}
        """
    )
}

private extension Array where Element == EvaluationSectionRule {
    static let defaultInterviewSections: [EvaluationSectionRule] = [
        .init(id: "conclusion", kind: .conclusion, title: "结论", instruction: "输出建议通过、保留复核或不建议通过，并给出置信度和一句理由", maximumItems: 3, minimumCharacters: 1, maximumCharacters: 120, isRequired: true),
        .init(id: "total", kind: .totalScore, title: "综合评分", instruction: "输出五项分数之和", maximumItems: 1, minimumCharacters: 1, maximumCharacters: 10, isRequired: true),
        .init(id: "dimensions", kind: .dimensionScores, title: "分项评分", instruction: "逐项输出分数和一句理由", maximumItems: 5, minimumCharacters: 20, maximumCharacters: 60, isRequired: true),
        .init(id: "logic-analysis", kind: .logicAnalysis, title: "逻辑分析", instruction: "说明重复出现的逻辑问题和改进方向", maximumItems: 3, minimumCharacters: 30, maximumCharacters: 80, isRequired: true),
        .init(id: "summary", kind: .summary, title: "总评", instruction: "概括岗位适配特点和整体表现", maximumItems: 1, minimumCharacters: 100, maximumCharacters: 150, isRequired: true),
        .init(id: "strengths", kind: .strengths, title: "优势", instruction: "只写核心优势及事实依据", maximumItems: 3, minimumCharacters: 30, maximumCharacters: 60, isRequired: false),
        .init(id: "weaknesses", kind: .weaknesses, title: "劣势", instruction: "只写核心不足及事实依据", maximumItems: 3, minimumCharacters: 30, maximumCharacters: 60, isRequired: false),
        .init(id: "risks", kind: .risks, title: "风险", instruction: "只写需要复核的核心风险", maximumItems: 3, minimumCharacters: 30, maximumCharacters: 60, isRequired: false)
    ]

    static let defaultResumeSections: [EvaluationSectionRule] = [
        .init(id: "resume-summary", kind: .summary, title: "总评", instruction: "概括经历结构、岗位匹配和可迁移能力", maximumItems: 1, minimumCharacters: 60, maximumCharacters: 100, isRequired: true),
        .init(id: "resume-strengths", kind: .strengths, title: "优势", instruction: "说明项目规模、业务领域、职责和可迁移能力", maximumItems: 1, minimumCharacters: 60, maximumCharacters: 100, isRequired: false),
        .init(id: "resume-weaknesses", kind: .weaknesses, title: "劣势", instruction: "说明目标岗位能力与现有经历的缺口", maximumItems: 1, minimumCharacters: 60, maximumCharacters: 100, isRequired: false),
        .init(id: "resume-risks", kind: .risks, title: "风险", instruction: "说明成果归因、角色边界、时间线或能力疑点", maximumItems: 1, minimumCharacters: 60, maximumCharacters: 100, isRequired: false),
        .init(id: "resume-questions", kind: .questions, title: "建议问题", instruction: "生成可直接询问候选人的问题", maximumItems: 5, minimumCharacters: 5, maximumCharacters: 60, isRequired: true)
    ]
}
