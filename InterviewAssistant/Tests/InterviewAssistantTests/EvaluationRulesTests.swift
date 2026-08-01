import Foundation
import InterviewAssistantCore

enum EvaluationRulesTests {
    static let all = [
        TestCase(name: "默认评价规则保持当前评分和阈值") {
            let rules = EvaluationRulesConfiguration.default

            try expect(
                rules.interview.dimensions.map(\.maximum)
                    .reduce(0, +) == 100,
                "默认评分总和应为100"
            )
            try expect(
                rules.interview.thresholds.recommendedMinimum == 75,
                "建议通过线应为75"
            )
            try expect(
                rules.interview.thresholds.reviewMinimum == 60,
                "保留复核线应为60"
            )
            try expect(
                rules.resume.questionCount == 5,
                "简历初评应默认生成5个问题"
            )
            for variable in ["{{transcript}}", "{{outputContract}}"] {
                try expect(
                    rules.interview.advancedPromptTemplate
                        .contains(variable),
                    "面试高级模板缺少变量\(variable)"
                )
            }
            for variable in ["{{resume}}", "{{outputContract}}"] {
                try expect(
                    rules.resume.advancedPromptTemplate
                        .contains(variable),
                    "简历高级模板缺少变量\(variable)"
                )
            }
        },
        TestCase(name: "规则校验拒绝错误分值阈值和模板") {
            var wrongTotal = EvaluationRulesConfiguration.default
            wrongTotal.interview.dimensions[0].maximum = 24
            try expectValidationFailure(wrongTotal, contains: "100")

            var wrongThreshold = EvaluationRulesConfiguration.default
            wrongThreshold.interview.thresholds.reviewMinimum = 80
            try expectValidationFailure(
                wrongThreshold,
                contains: "通过线"
            )

            var duplicate = EvaluationRulesConfiguration.default
            duplicate.interview.dimensions[1].id =
                duplicate.interview.dimensions[0].id
            try expectValidationFailure(duplicate, contains: "重复")

            var missingVariable = EvaluationRulesConfiguration.default
            missingVariable.resume.promptMode = .advanced
            missingVariable.resume.advancedPromptTemplate =
                "只根据简历评价 {{resume}}"
            try expectValidationFailure(
                missingVariable,
                contains: "outputContract"
            )
        },
        TestCase(name: "评价规则本机保存并在损坏时回退") {
            let root = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            defer { try? FileManager.default.removeItem(at: root) }
            let store = EvaluationRulesStore(root: root)

            try store.save(.default)
            var changed = EvaluationRulesConfiguration.default
            changed.interview.dimensions[0].instruction = "先给结论"
            try store.save(changed)

            let restored = store.load()
            try expect(restored == changed, "应恢复当前启用规则")

            try Data("损坏".utf8).write(
                to: root.appendingPathComponent("current.json")
            )
            let fallback = store.load()
            try expect(
                fallback == .default,
                "当前文件损坏时应读取上一次有效规则"
            )
        },
        TestCase(name: "无效规则不会覆盖当前配置") {
            let root = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            defer { try? FileManager.default.removeItem(at: root) }
            let store = EvaluationRulesStore(root: root)
            try store.save(.default)
            var invalid = EvaluationRulesConfiguration.default
            invalid.interview.dimensions.removeLast()

            var didThrow = false
            do {
                try store.save(invalid)
            } catch {
                didThrow = true
            }

            try expect(didThrow, "无效规则保存应失败")
            try expect(
                store.load() == .default,
                "保存失败后应保留当前规则"
            )
        },
        TestCase(name: "规则标题拒绝结构分隔符和换行") {
            var dimension = EvaluationRulesConfiguration.default
            dimension.interview.dimensions[0].title = "沟通：表达"
            try expectValidationFailure(dimension, contains: "分隔符")

            var section = EvaluationRulesConfiguration.default
            section.resume.sections[0].title = "总评\n补充"
            try expectValidationFailure(section, contains: "换行")
        },
        TestCase(name: "固定结构字段必须与系统规则一致") {
            var questions = EvaluationRulesConfiguration.default
            let questionIndex = questions.resume.sections.firstIndex {
                $0.kind == .questions
            }!
            questions.resume.sections[questionIndex].maximumItems = 2
            try expectValidationFailure(questions, contains: "问题数量")

            var dimensions = EvaluationRulesConfiguration.default
            let dimensionIndex = dimensions.interview.sections.firstIndex {
                $0.kind == .dimensionScores
            }!
            dimensions.interview.sections[dimensionIndex].maximumItems = 2
            try expectValidationFailure(dimensions, contains: "评分维度")
        }
    ]

    private static func expectValidationFailure(
        _ rules: EvaluationRulesConfiguration,
        contains expected: String
    ) throws {
        do {
            try EvaluationRulesValidator.validate(rules)
            throw TestFailure(description: "规则本应校验失败")
        } catch let error as EvaluationRulesValidationError {
            try expect(
                error.localizedDescription.contains(expected),
                "错误提示应包含\(expected)，实际为\(error.localizedDescription)"
            )
        }
    }
}
