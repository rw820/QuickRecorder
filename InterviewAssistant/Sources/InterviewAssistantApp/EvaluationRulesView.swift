import InterviewAssistantCore
import SwiftUI

struct EvaluationRulesView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: EvaluationRulesEditorModel
    @State private var tab = RulesTab.interview
    @State private var node = RulesNode.dimensions
    @State private var errorMessage: String?
    @State private var showsPreview = false
    @State private var previewTarget = EvaluationRulesPreviewTarget.interview

    init(store: EvaluationRulesStore = EvaluationRulesStore()) {
        _model = StateObject(
            wrappedValue: EvaluationRulesEditorModel(store: store)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            Picker("规则类型", selection: $tab) {
                ForEach(RulesTab.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 18)
            .padding(.vertical, 12)

            Divider()
            if tab == .advanced {
                advancedEditor
            } else {
                structuredEditor
            }
        }
        .frame(minWidth: 1_080, minHeight: 720)
        .sheet(isPresented: $showsPreview) {
            promptPreview
        }
        .alert(
            "规则无法保存",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("好", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "请检查规则")
        }
        .onChange(of: tab) {
            node = tab == .resume ? .sections : .dimensions
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("评价规则")
                    .font(.title2.bold())
                Text(model.statusMessage ?? "修改草稿，保存后用于下一次评价")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("恢复默认") {
                model.restoreDefaultDraft()
            }
            Button {
                previewTarget = tab == .resume ? .resume : .interview
                showsPreview = true
            } label: {
                Label("查看最终提示词", systemImage: "doc.text.magnifyingglass")
            }
            Button("保存并启用") {
                do {
                    try model.saveAndActivate()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
            .buttonStyle(.borderedProminent)
            Button("完成") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(18)
    }

    private var structuredEditor: some View {
        HSplitView {
            navigation
                .frame(minWidth: 170, idealWidth: 185, maxWidth: 210)
            flowCanvas
                .frame(minWidth: 360, idealWidth: 440)
            detailEditor
                .frame(minWidth: 390, idealWidth: 430)
        }
    }

    private var navigation: some View {
        List(selection: $node) {
            if tab == .interview {
                navRow(.inputs, "输入与证据", "doc.text")
                navRow(.logic, "逻辑检查", "checklist")
                navRow(.dimensions, "评分维度", "chart.bar")
                navRow(.thresholds, "通过规则", "signpost.right")
                navRow(.sections, "输出结构", "square.stack.3d.up")
            } else {
                navRow(.inputs, "评价原则", "doc.text")
                navRow(.sections, "输出结构", "square.stack.3d.up")
                navRow(.questions, "建议问题", "questionmark.bubble")
            }
        }
        .listStyle(.sidebar)
    }

    private func navRow(
        _ value: RulesNode,
        _ title: String,
        _ icon: String
    ) -> some View {
        Label(title, systemImage: icon).tag(value)
    }

    private var flowCanvas: some View {
        ScrollView {
            VStack(spacing: 9) {
                Text(tab == .interview ? "面试评价生成流程" : "简历初评生成流程")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 6)

                flowCard(.inputs, title: "① 输入材料") {
                    Text(
                        tab == .interview
                            ? "逐字稿 + 可选简历 + 手工要求"
                            : "简历文字 + 手工要求"
                    )
                }
                flowArrow
                if tab == .interview {
                    flowCard(.logic, title: "② 证据与逻辑检查") {
                        Text("\(model.draft.interview.logicChecks.count) 项检查规则")
                    }
                    flowArrow
                    flowCard(.dimensions, title: "③ 评分维度") {
                        let total = model.draft.interview.dimensions
                            .map(\.maximum).reduce(0, +)
                        Text("\(model.draft.interview.dimensions.count) 项 · 合计 \(total) 分")
                            .foregroundStyle(
                                total == 100
                                    ? Color.secondary
                                    : Color.red
                            )
                    }
                    flowArrow
                    flowCard(.thresholds, title: "④ 结论判断") {
                        Text(
                            "≥\(model.draft.interview.thresholds.recommendedMinimum) 建议通过 · ≥\(model.draft.interview.thresholds.reviewMinimum) 保留复核"
                        )
                    }
                    flowArrow
                }
                flowCard(.sections, title: tab == .interview ? "⑤ 输出结构" : "② 输出结构") {
                    let sections = tab == .interview
                        ? model.draft.interview.sections
                        : model.draft.resume.sections
                    Text(sections.map(\.title).joined(separator: " · "))
                        .lineLimit(3)
                }
                if tab == .resume {
                    flowArrow
                    flowCard(.questions, title: "③ 建议问题") {
                        Text("固定生成 \(model.draft.resume.questionCount) 个问题")
                    }
                }
            }
            .foregroundStyle(.primary)
            .padding(20)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func flowCard<Content: View>(
        _ target: RulesNode,
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Button {
            node = target
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline)
                content()
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                node == target
                    ? Color.accentColor.opacity(0.10)
                    : Color(nsColor: .textBackgroundColor),
                in: RoundedRectangle(cornerRadius: 11)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 11)
                    .stroke(
                        node == target
                            ? Color.accentColor
                            : Color.secondary.opacity(0.18),
                        lineWidth: node == target ? 2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
    }

    private var flowArrow: some View {
        Image(systemName: "arrow.down")
            .foregroundStyle(.tertiary)
    }

    @ViewBuilder
    private var detailEditor: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if tab == .interview {
                    interviewDetail
                } else {
                    resumeDetail
                }
            }
            .padding(18)
        }
    }

    @ViewBuilder
    private var interviewDetail: some View {
        switch node {
        case .inputs:
            editorTitle("输入与证据")
            fieldLabel("基础角色要求")
            TextEditor(text: $model.draft.interview.baseInstruction)
                .editorBox(minHeight: 80)
            fieldLabel("事实与公平约束")
            stringList($model.draft.interview.evidenceRules)
        case .logic:
            editorTitle("逻辑检查")
            stringList($model.draft.interview.logicChecks)
        case .dimensions:
            editorTitle("评分维度")
            ForEach($model.draft.interview.dimensions) { $dimension in
                dimensionEditor($dimension)
            }
            Button {
                model.addInterviewDimension()
            } label: {
                Label("增加评分项", systemImage: "plus")
            }
        case .thresholds:
            editorTitle("通过规则")
            Stepper(
                "建议通过：\(model.draft.interview.thresholds.recommendedMinimum) 分及以上",
                value: $model.draft.interview.thresholds.recommendedMinimum,
                in: 1...100
            )
            Stepper(
                "保留复核：\(model.draft.interview.thresholds.reviewMinimum) 分及以上",
                value: $model.draft.interview.thresholds.reviewMinimum,
                in: 0...99
            )
        case .sections:
            editorTitle("输出结构")
            ForEach($model.draft.interview.sections) { $section in
                sectionEditor(
                    $section,
                    moveUp: {
                        model.moveInterviewSection(
                            id: section.id,
                            offset: -1
                        )
                    },
                    moveDown: {
                        model.moveInterviewSection(
                            id: section.id,
                            offset: 1
                        )
                    },
                    remove: {
                        _ = model.removeInterviewSection(id: section.id)
                    }
                )
            }
            Button {
                model.addInterviewSection()
            } label: {
                Label("增加自定义板块", systemImage: "plus")
            }
        case .questions:
            EmptyView()
        }
    }

    @ViewBuilder
    private var resumeDetail: some View {
        switch node {
        case .inputs:
            editorTitle("简历评价原则")
            fieldLabel("基础角色要求")
            TextEditor(text: $model.draft.resume.baseInstruction)
                .editorBox(minHeight: 80)
            stringList($model.draft.resume.principles)
        case .sections:
            editorTitle("输出结构")
            ForEach($model.draft.resume.sections) { $section in
                sectionEditor(
                    $section,
                    moveUp: {
                        model.moveResumeSection(
                            id: section.id,
                            offset: -1
                        )
                    },
                    moveDown: {
                        model.moveResumeSection(
                            id: section.id,
                            offset: 1
                        )
                    },
                    remove: {
                        _ = model.removeResumeSection(id: section.id)
                    }
                )
            }
            Button {
                model.addResumeSection()
            } label: {
                Label("增加自定义板块", systemImage: "plus")
            }
        case .questions:
            editorTitle("建议问题")
            Stepper(
                "固定生成 \(model.draft.resume.questionCount) 个问题",
                value: $model.draft.resume.questionCount,
                in: 1...20
            )
        default:
            Text("请选择一项规则")
                .foregroundStyle(.secondary)
        }
    }

    private func dimensionEditor(
        _ dimension: Binding<ScoreDimensionRule>
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                TextField("维度名称", text: dimension.title)
                    .textFieldStyle(.roundedBorder)
                Stepper(
                    "\(dimension.wrappedValue.maximum) 分",
                    value: dimension.maximum,
                    in: 1...100
                )
                Button {
                    model.moveInterviewDimension(
                        id: dimension.wrappedValue.id,
                        offset: -1
                    )
                } label: {
                    Image(systemName: "arrow.up")
                }
                .buttonStyle(.borderless)
                Button {
                    model.moveInterviewDimension(
                        id: dimension.wrappedValue.id,
                        offset: 1
                    )
                } label: {
                    Image(systemName: "arrow.down")
                }
                .buttonStyle(.borderless)
                Button(role: .destructive) {
                    _ = model.removeInterviewDimension(
                        id: dimension.wrappedValue.id
                    )
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
            TextEditor(text: dimension.instruction)
                .editorBox(minHeight: 58)
            HStack {
                Text("理由字数")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField(
                    "最少",
                    value: dimension.reasonMinimumCharacters,
                    format: .number
                )
                .frame(width: 56)
                Text("至")
                TextField(
                    "最多",
                    value: dimension.reasonMaximumCharacters,
                    format: .number
                )
                .frame(width: 56)
            }
        }
        .ruleCard()
    }

    private func sectionEditor(
        _ section: Binding<EvaluationSectionRule>,
        moveUp: @escaping () -> Void,
        moveDown: @escaping () -> Void,
        remove: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                TextField("板块标题", text: section.title)
                    .textFieldStyle(.roundedBorder)
                Button(action: moveUp) {
                    Image(systemName: "arrow.up")
                }
                .buttonStyle(.borderless)
                Button(action: moveDown) {
                    Image(systemName: "arrow.down")
                }
                .buttonStyle(.borderless)
                if section.wrappedValue.isRequired {
                    Text("必需")
                        .font(.caption2.bold())
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.1), in: Capsule())
                } else {
                    Button(role: .destructive, action: remove) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }
            }
            TextEditor(text: section.instruction)
                .editorBox(minHeight: 55)
            switch section.wrappedValue.kind {
            case .dimensionScores:
                fixedSetting("条数跟随评分维度；理由字数在评分维度中设置")
            case .totalScore:
                fixedSetting("固定输出一行“数字/100”")
            case .questions:
                HStack {
                    Text("条数跟随“固定生成问题数”")
                        .foregroundStyle(.secondary)
                    Spacer()
                    lengthFields(section)
                }
                .font(.caption)
            case .conclusion:
                HStack {
                    Text("固定输出结论、置信度、理由三行")
                        .foregroundStyle(.secondary)
                    Spacer()
                    lengthFields(section)
                }
                .font(.caption)
            default:
                HStack {
                    Stepper(
                        "最多 \(section.wrappedValue.maximumItems) 条",
                        value: section.maximumItems,
                        in: 1...20
                    )
                    Spacer()
                    lengthFields(section)
                }
                .font(.caption)
            }
        }
        .ruleCard()
    }

    private func fixedSetting(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func lengthFields(
        _ section: Binding<EvaluationSectionRule>
    ) -> some View {
        TextField(
            "最少字数",
            value: section.minimumCharacters,
            format: .number
        )
        .frame(width: 70)
        Text("至")
        TextField(
            "最多字数",
            value: section.maximumCharacters,
            format: .number
        )
        .frame(width: 70)
    }

    private func stringList(_ values: Binding<[String]>) -> some View {
        VStack(spacing: 8) {
            ForEach(values.wrappedValue.indices, id: \.self) { index in
                HStack {
                    TextField("规则", text: values[index])
                        .textFieldStyle(.roundedBorder)
                    Button(role: .destructive) {
                        values.wrappedValue.remove(at: index)
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                }
            }
            Button {
                values.wrappedValue.append("新规则")
            } label: {
                Label("增加规则", systemImage: "plus")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var advancedEditor: some View {
        HSplitView {
            advancedTemplate(
                title: "面试评价完整提示词",
                mode: $model.draft.interview.promptMode,
                text: $model.draft.interview.advancedPromptTemplate
            )
            advancedTemplate(
                title: "简历初评完整提示词",
                mode: $model.draft.resume.promptMode,
                text: $model.draft.resume.advancedPromptTemplate
            )
        }
        .padding(18)
    }

    private func advancedTemplate(
        title: String,
        mode: Binding<PromptEditingMode>,
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            Picker("使用模式", selection: mode) {
                Text("结构化规则").tag(PromptEditingMode.structured)
                Text("完整提示词").tag(PromptEditingMode.advanced)
            }
            .pickerStyle(.segmented)
            Text("可用变量：{{transcript}}、{{resume}}、{{customRequirement}}、{{outputContract}}")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: text)
                .font(.system(.body, design: .monospaced))
                .editorBox(minHeight: 500)
        }
        .padding(14)
        .background(
            Color(nsColor: .controlBackgroundColor),
            in: RoundedRectangle(cornerRadius: 12)
        )
    }

    private var promptPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("最终提示词预览")
                    .font(.title2.bold())
                Spacer()
                Button("完成") { showsPreview = false }
            }
            Picker("预览类型", selection: $previewTarget) {
                Text("面试评价")
                    .tag(EvaluationRulesPreviewTarget.interview)
                Text("简历初评")
                    .tag(EvaluationRulesPreviewTarget.resume)
            }
            .pickerStyle(.segmented)
            ScrollView {
                Text(
                    model.preview(for: previewTarget)
                )
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
            }
            .background(
                Color(nsColor: .textBackgroundColor),
                in: RoundedRectangle(cornerRadius: 10)
            )
        }
        .padding(18)
        .frame(minWidth: 760, minHeight: 620)
    }

    private func editorTitle(_ title: String) -> some View {
        Text(title).font(.title3.bold())
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption.bold())
            .foregroundStyle(.secondary)
    }
}

private enum RulesTab: String, CaseIterable, Identifiable {
    case interview
    case resume
    case advanced

    var id: Self { self }

    var title: String {
        switch self {
        case .interview: "面试评价"
        case .resume: "简历初评"
        case .advanced: "高级提示词"
        }
    }
}

private enum RulesNode: String, Hashable {
    case inputs
    case logic
    case dimensions
    case thresholds
    case sections
    case questions
}

private extension View {
    func editorBox(minHeight: CGFloat) -> some View {
        frame(minHeight: minHeight)
            .padding(5)
            .background(
                Color(nsColor: .textBackgroundColor),
                in: RoundedRectangle(cornerRadius: 7)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.secondary.opacity(0.25))
            }
    }

    func ruleCard() -> some View {
        padding(12)
            .background(
                Color(nsColor: .controlBackgroundColor),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.secondary.opacity(0.15))
            }
    }
}
