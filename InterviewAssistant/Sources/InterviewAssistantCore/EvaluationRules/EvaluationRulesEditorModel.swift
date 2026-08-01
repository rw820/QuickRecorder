import Combine
import Foundation

@MainActor
public final class EvaluationRulesEditorModel: ObservableObject {
    @Published public var draft: EvaluationRulesConfiguration
    @Published public private(set) var statusMessage: String?

    private let store: EvaluationRulesStore

    public init(store: EvaluationRulesStore = EvaluationRulesStore()) {
        self.store = store
        self.draft = store.load()
    }

    public func saveAndActivate() throws {
        synchronizeDerivedFields()
        try store.save(draft)
        statusMessage = "规则已保存并启用"
    }

    public func restoreDefaultDraft() {
        draft = .default
        statusMessage = "已恢复默认草稿，保存后生效"
    }

    public func preview(
        for target: EvaluationRulesPreviewTarget
    ) -> String {
        synchronizeDerivedFields()
        return EvaluationPromptComposer.preview(
            configuration: draft,
            target: target
        )
    }

    public func addInterviewDimension() {
        draft.interview.dimensions.append(
            ScoreDimensionRule(
                id: UUID().uuidString,
                title: "新评分项",
                maximum: 1,
                instruction: "填写评价重点"
            )
        )
        synchronizeDerivedFields()
    }

    public func moveInterviewDimension(id: String, offset: Int) {
        move(id: id, offset: offset, values: &draft.interview.dimensions)
    }

    @discardableResult
    public func removeInterviewDimension(id: String) -> Bool {
        guard draft.interview.dimensions.count > 1 else { return false }
        let oldCount = draft.interview.dimensions.count
        draft.interview.dimensions.removeAll { $0.id == id }
        synchronizeDerivedFields()
        return draft.interview.dimensions.count != oldCount
    }

    public func addInterviewSection() {
        draft.interview.sections.append(
            EvaluationSectionRule(
                id: UUID().uuidString,
                kind: .custom,
                title: "自定义板块",
                instruction: "填写本板块的评价要求",
                maximumItems: 3,
                minimumCharacters: 10,
                maximumCharacters: 60,
                isRequired: false
            )
        )
    }

    public func moveInterviewSection(id: String, offset: Int) {
        move(id: id, offset: offset, values: &draft.interview.sections)
    }

    @discardableResult
    public func removeInterviewSection(id: String) -> Bool {
        guard let section = draft.interview.sections.first(
            where: { $0.id == id }
        ), !section.isRequired else {
            return false
        }
        draft.interview.sections.removeAll { $0.id == id }
        return true
    }

    public func addResumeSection() {
        draft.resume.sections.append(
            EvaluationSectionRule(
                id: UUID().uuidString,
                kind: .custom,
                title: "自定义板块",
                instruction: "填写本板块的评价要求",
                maximumItems: 1,
                minimumCharacters: 20,
                maximumCharacters: 100,
                isRequired: false
            )
        )
    }

    public func moveResumeSection(id: String, offset: Int) {
        move(id: id, offset: offset, values: &draft.resume.sections)
    }

    @discardableResult
    public func removeResumeSection(id: String) -> Bool {
        guard let section = draft.resume.sections.first(
            where: { $0.id == id }
        ), !section.isRequired else {
            return false
        }
        draft.resume.sections.removeAll { $0.id == id }
        return true
    }

    private func synchronizeDerivedFields() {
        let dimensionCount = draft.interview.dimensions.count
        if let index = draft.interview.sections.firstIndex(
            where: { $0.kind == .dimensionScores }
        ) {
            draft.interview.sections[index].maximumItems = dimensionCount
            draft.interview.sections[index].minimumCharacters =
                draft.interview.dimensions
                    .map(\.reasonMinimumCharacters).min() ?? 1
            draft.interview.sections[index].maximumCharacters =
                draft.interview.dimensions
                    .map(\.reasonMaximumCharacters).max() ?? 1
        }
        if let index = draft.interview.sections.firstIndex(
            where: { $0.kind == .conclusion }
        ) {
            draft.interview.sections[index].maximumItems = 3
        }
        if let index = draft.interview.sections.firstIndex(
            where: { $0.kind == .totalScore }
        ) {
            draft.interview.sections[index].maximumItems = 1
            draft.interview.sections[index].minimumCharacters = 1
            draft.interview.sections[index].maximumCharacters = 10
        }
        if let index = draft.resume.sections.firstIndex(
            where: { $0.kind == .questions }
        ) {
            draft.resume.sections[index].maximumItems =
                draft.resume.questionCount
        }
    }

    private func move<Value: Identifiable>(
        id: Value.ID,
        offset: Int,
        values: inout [Value]
    ) where Value.ID: Equatable {
        guard
            let source = values.firstIndex(where: { $0.id == id })
        else {
            return
        }
        let destination = source + offset
        guard values.indices.contains(destination) else { return }
        let value = values.remove(at: source)
        values.insert(value, at: destination)
    }
}
