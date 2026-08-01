import Foundation
import InterviewAssistantCore

enum EvaluationRulesEditorModelTests {
    static let all = [
        TestCase(name: "规则编辑草稿只有保存后才启用") {
            let root = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            defer { try? FileManager.default.removeItem(at: root) }
            let store = EvaluationRulesStore(root: root)
            try store.save(.default)
            let model = EvaluationRulesEditorModel(store: store)
            model.draft.interview.dimensions[0].instruction = "新的规则"

            try expect(
                store.load() == .default,
                "未保存草稿不应影响启用规则"
            )

            try model.saveAndActivate()
            try expect(
                store.load().interview.dimensions[0].instruction
                    == "新的规则",
                "保存后应启用草稿"
            )
        },
        TestCase(name: "恢复默认只重置草稿且可预览提示词") {
            let root = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            defer { try? FileManager.default.removeItem(at: root) }
            let store = EvaluationRulesStore(root: root)
            var changed = EvaluationRulesConfiguration.default
            changed.interview.thresholds.recommendedMinimum = 80
            try store.save(changed)
            let model = EvaluationRulesEditorModel(store: store)

            model.restoreDefaultDraft()

            try expect(
                model.draft == .default,
                "恢复默认应重置编辑草稿"
            )
            try expect(
                store.load() == changed,
                "未保存时当前规则不应改变"
            )
            try expect(
                model.preview(for: .interview).contains("## 结论"),
                "应能预览最终提示词"
            )
        },
        TestCase(name: "必需板块不可删除而自定义板块可以删除") {
            let model = EvaluationRulesEditorModel(
                store: EvaluationRulesStore(
                    root: FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                )
            )
            let requiredID = model.draft.interview.sections[0].id
            try expect(
                !model.removeInterviewSection(id: requiredID),
                "必需板块不应删除"
            )
            model.addInterviewSection()
            guard let customID = model.draft.interview.sections.last?.id
            else {
                throw TestFailure(description: "应新增自定义板块")
            }
            try expect(
                model.removeInterviewSection(id: customID),
                "自定义板块应允许删除"
            )
        },
        TestCase(name: "评分项和输出板块可以调整顺序") {
            let model = EvaluationRulesEditorModel(
                store: EvaluationRulesStore(
                    root: FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                )
            )
            let firstDimension = model.draft.interview.dimensions[0].id
            let firstSection = model.draft.resume.sections[0].id

            model.moveInterviewDimension(id: firstDimension, offset: 1)
            model.moveResumeSection(id: firstSection, offset: 1)

            try expect(
                model.draft.interview.dimensions[1].id == firstDimension,
                "评分项应下移"
            )
            try expect(
                model.draft.resume.sections[1].id == firstSection,
                "简历板块应下移"
            )
        },
        TestCase(name: "保存时同步固定结构字段") {
            let root = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            defer { try? FileManager.default.removeItem(at: root) }
            let store = EvaluationRulesStore(root: root)
            let model = EvaluationRulesEditorModel(store: store)
            model.draft.resume.questionCount = 7
            model.addInterviewDimension()
            model.draft.interview.dimensions[0].maximum -= 1

            try model.saveAndActivate()

            let saved = store.load()
            let questionSection = saved.resume.sections.first {
                $0.kind == .questions
            }
            let dimensionSection = saved.interview.sections.first {
                $0.kind == .dimensionScores
            }
            try expect(
                questionSection?.maximumItems == 7,
                "建议问题板块条数应跟随固定问题数"
            )
            try expect(
                dimensionSection?.maximumItems
                    == saved.interview.dimensions.count,
                "分项评分条数应跟随评分维度"
            )
        }
    ]
}
