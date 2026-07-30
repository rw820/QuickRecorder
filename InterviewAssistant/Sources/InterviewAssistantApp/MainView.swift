import AppKit
import InterviewAssistantCore
import SwiftUI
import UniformTypeIdentifiers

struct MainView: View {
    @ObservedObject var controller: SessionController
    let hub: AudioTapHub

    @State private var systemActive = false
    @State private var microphoneActive = false
    @State private var showsResumeImporter = false
    @State private var showsHistory = false
    @State private var isResumeDropTarget = false
    @State private var showsEvaluationRefresh = false
    @State private var evaluationRefreshRequirement = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(minWidth: 820, minHeight: 620)
        .task {
            await updateActivity()
        }
        .fileImporter(
            isPresented: $showsResumeImporter,
            allowedContentTypes: supportedResumeTypes,
            allowsMultipleSelection: false
        ) { result in
            guard
                case let .success(urls) = result,
                let url = urls.first
            else {
                return
            }
            Task { await controller.importResume(from: url) }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard
                let url = urls.first,
                supportedResumeExtensions.contains(
                    url.pathExtension.lowercased()
                )
            else {
                return false
            }
            Task { await controller.importResume(from: url) }
            return true
        } isTargeted: { targeted in
            isResumeDropTarget = targeted
        }
        .sheet(isPresented: $showsHistory) {
            HistoryBrowserView(store: InterviewHistoryStore())
        }
        .sheet(isPresented: $showsEvaluationRefresh) {
            evaluationRefreshSheet
        }
        .overlay {
            if isResumeDropTarget {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        Color.accentColor,
                        style: StrokeStyle(
                            lineWidth: 3,
                            dash: [8, 5]
                        )
                    )
                    .padding(8)
                    .allowsHitTesting(false)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(InterviewAssistantCore.displayName)
                        .font(.title2.bold())
                    Text(recordingStatus)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
                Button {
                    showsHistory = true
                } label: {
                    Label(
                        "历史记录",
                        systemImage: "clock.arrow.circlepath"
                    )
                }
                resumeAction
                action
            }

            HStack(spacing: 20) {
                activityIndicator("候选人声音", active: systemActive)
                activityIndicator("面试官麦克风", active: microphoneActive)

                Label(
                    controller.assistantStatus,
                    systemImage: "text.bubble"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Spacer()
            }

            if let resume = controller.resume {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.fill")
                        .foregroundStyle(.blue)
                    Text(resume.originalFileName)
                        .font(.caption.bold())
                        .lineLimit(1)
                    Text(controller.resumeStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("清除") {
                        Task { await controller.clearResume() }
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .disabled(
                        controller.state != .idle
                            || controller.isImportingResume
                    )
                }
                .padding(9)
                .background(
                    Color.blue.opacity(0.07),
                    in: RoundedRectangle(cornerRadius: 8)
                )
            } else if controller.isImportingResume {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(controller.resumeStatus)
                        .font(.caption)
                    Spacer()
                }
            }

            if let warning = controller.warning {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(warning)
                        .lineLimit(2)
                    Spacer()
                }
                .font(.caption)
                .foregroundStyle(.orange)
            }
        }
        .padding(20)
    }

    @ViewBuilder
    private var content: some View {
        if let evaluation = controller.evaluation {
            evaluationView(evaluation)
        } else {
            HStack(spacing: 0) {
                transcriptView
                    .frame(maxWidth: .infinity)
                Divider()
                suggestionsView
                    .frame(width: 310)
            }
        }
    }

    private var transcriptView: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                "实时逐字稿",
                detail: "\(controller.transcript.count) 条"
            )

            if controller.transcript.isEmpty
                && controller.partialTranscripts.isEmpty
            {
                emptyState(
                    icon: "waveform",
                    text: isRecording
                        ? "正在等待对话…"
                        : "开始面试后，文字会出现在这里"
                )
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            ForEach(controller.transcript) { line in
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(line.speakerName)
                                        .font(.caption.bold())
                                        .foregroundStyle(
                                            line.source == .system
                                                ? .blue
                                                : .secondary
                                        )
                                    Text(line.displayText)
                                        .textSelection(.enabled)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(
                                    Color.primary.opacity(0.045),
                                    in: RoundedRectangle(cornerRadius: 8)
                                )
                                .id(line.id)
                            }
                            ForEach(
                                [AudioSource.system, .microphone],
                                id: \.rawValue
                            ) { source in
                                if let text =
                                    controller.partialTranscripts[source]
                                {
                                    VStack(
                                        alignment: .leading,
                                        spacing: 3
                                    ) {
                                        Text(
                                            source == .system
                                                ? "候选人 · 识别中"
                                                : "面试官 · 识别中"
                                        )
                                        .font(.caption.bold())
                                        .foregroundStyle(.secondary)
                                        Text(text)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(
                                        maxWidth: .infinity,
                                        alignment: .leading
                                    )
                                    .padding(10)
                                    .background(
                                        Color.blue.opacity(0.06),
                                        in: RoundedRectangle(cornerRadius: 8)
                                    )
                                }
                            }
                        }
                    }
                    .onChange(of: controller.transcript.count) {
                        if let id = controller.transcript.last?.id {
                            withAnimation {
                                proxy.scrollTo(id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .padding(18)
    }

    private var suggestionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("建议追问", detail: "最多 3 条")

            if controller.suggestions.isEmpty {
                emptyState(
                    icon: "lightbulb",
                    text: isRecording
                        ? "候选人回答后自动生成"
                        : "开始面试后自动分析"
                )
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(controller.suggestions) { suggestion in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(suggestion.question)
                                    .font(.headline)
                                    .textSelection(.enabled)
                                Text(suggestion.reason)
                                    .font(.subheadline)
                                Text(suggestion.evidence)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )
                            .padding(12)
                            .background(
                                Color.accentColor.opacity(0.08),
                                in: RoundedRectangle(cornerRadius: 10)
                            )
                        }
                    }
                }
            }
        }
        .padding(18)
    }

    private func evaluationView(
        _ evaluation: InterviewEvaluation
    ) -> some View {
        let scorecard = controller.evaluationTitle == "本次面试评价"
            ? InterviewEvaluationScorecard.parse(from: evaluation.markdown)
            : nil
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader(
                    controller.evaluationTitle,
                    detail: "已生成"
                )
                Spacer()
                if controller.canRefreshCurrentEvaluation
                    || controller.isRefreshingEvaluation
                {
                    Button {
                        evaluationRefreshRequirement = ""
                        showsEvaluationRefresh = true
                    } label: {
                        if controller.isRefreshingEvaluation {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label(
                                controller.evaluationTitle == "简历初评"
                                    ? "刷新评价和问题"
                                    : "刷新评价",
                                systemImage: "arrow.clockwise"
                            )
                        }
                    }
                    .disabled(controller.isRefreshingEvaluation)
                }
                if let directory = controller.lastSessionDirectory {
                    Button("打开本次文件") {
                        NSWorkspace.shared.open(directory)
                    }
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let scorecard {
                        recommendationCard(scorecard)
                        dimensionScores(scorecard.dimensions)
                        evaluationSection(
                            "逻辑分析",
                            text: scorecard.logicFindings
                                .map { "- \($0)" }
                                .joined(separator: "\n"),
                            color: .indigo
                        )
                    }
                    evaluationSection(
                        "总评",
                        text: section("总评", in: evaluation.markdown),
                        color: .blue
                    )
                    evaluationSection(
                        "优势",
                        text: section("优势", in: evaluation.markdown),
                        color: .green
                    )
                    evaluationSection(
                        "劣势",
                        text: section("劣势", in: evaluation.markdown),
                        color: .orange
                    )
                    evaluationSection(
                        "风险",
                        text: section("风险", in: evaluation.markdown),
                        color: .red
                    )
                    if controller.evaluationTitle == "简历初评" {
                        evaluationSection(
                            "建议问题",
                            text: section(
                                "建议问题",
                                in: evaluation.markdown
                            ),
                            color: .purple
                        )
                    }
                }
            }
        }
        .padding(18)
    }

    private func recommendationCard(
        _ scorecard: InterviewEvaluationScorecard
    ) -> some View {
        let color = recommendationColor(scorecard.recommendation)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Label(
                    scorecard.recommendation.title,
                    systemImage: recommendationIcon(
                        scorecard.recommendation
                    )
                )
                .font(.title3.bold())
                .foregroundStyle(color)

                Spacer()

                Text("\(scorecard.totalScore)/100")
                    .font(.title2.bold())
                    .monospacedDigit()
                Text("置信度：\(scorecard.confidence.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(scorecard.reason)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(16)
        .background(
            color.opacity(0.09),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.22))
        }
    }

    private func dimensionScores(
        _ dimensions: [InterviewEvaluationDimension]
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("分项评分", systemImage: "chart.bar.fill")
                .font(.headline)
                .foregroundStyle(.blue)

            ForEach(dimensions, id: \.title) { dimension in
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(dimension.title)
                            .font(.subheadline.bold())
                        Spacer()
                        Text("\(dimension.score)/\(dimension.maximum)")
                            .font(.subheadline.bold())
                            .monospacedDigit()
                    }
                    ProgressView(
                        value: Double(dimension.score),
                        total: Double(dimension.maximum)
                    )
                    .tint(.blue)
                    Text(dimension.reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(14)
        .background(
            Color.blue.opacity(0.06),
            in: RoundedRectangle(cornerRadius: 10)
        )
    }

    private func recommendationColor(
        _ recommendation: InterviewRecommendation
    ) -> Color {
        switch recommendation {
        case .recommended:
            .green
        case .review:
            .orange
        case .notRecommended:
            .red
        }
    }

    private func recommendationIcon(
        _ recommendation: InterviewRecommendation
    ) -> String {
        switch recommendation {
        case .recommended:
            "checkmark.circle.fill"
        case .review:
            "questionmark.circle.fill"
        case .notRecommended:
            "xmark.circle.fill"
        }
    }

    private func evaluationSection(
        _ title: String,
        text: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: "circle.fill")
                .font(.headline)
                .foregroundStyle(color)
            Text(text.isEmpty ? "待确认" : text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(14)
        .background(
            color.opacity(0.07),
            in: RoundedRectangle(cornerRadius: 10)
        )
    }

    private var evaluationRefreshSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(
                controller.evaluationTitle == "简历初评"
                    ? "刷新简历评价和问题"
                    : "刷新面试评价"
            )
            .font(.title3.bold())

            Text("可以填写本次要求，不填写则按默认规则刷新。")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextEditor(text: $evaluationRefreshRequirement)
                .font(.body)
                .frame(minHeight: 110)
                .padding(8)
                .background(
                    Color.primary.opacity(0.04),
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.12))
                }

            HStack {
                Spacer()
                Button("取消") {
                    showsEvaluationRefresh = false
                }
                Button("刷新") {
                    let requirement = evaluationRefreshRequirement
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    showsEvaluationRefresh = false
                    Task {
                        await controller.refreshCurrentEvaluation(
                            customRequirement: requirement.isEmpty
                                ? nil
                                : requirement
                        )
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 460)
    }

    private func section(
        _ name: String,
        in markdown: String
    ) -> String {
        let marker = "## \(name)"
        guard let markerRange = markdown.range(of: marker) else {
            return ""
        }
        let remainder = markdown[markerRange.upperBound...]
        let end = remainder.range(of: "\n## ")?.lowerBound
            ?? remainder.endIndex
        return String(remainder[..<end])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func sectionHeader(
        _ title: String,
        detail: String
    ) -> some View {
        HStack {
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func emptyState(
        icon: String,
        text: String
    ) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var resumeAction: some View {
        Button {
            showsResumeImporter = true
        } label: {
            Label(
                controller.resume == nil ? "导入简历" : "替换简历",
                systemImage: "doc.badge.plus"
            )
        }
        .buttonStyle(.bordered)
        .disabled(
            controller.state != .idle
                || controller.isImportingResume
                || controller.isRefreshingEvaluation
        )
    }

    @ViewBuilder
    private var action: some View {
        switch controller.state {
        case .recording:
            Button("停止并生成评价", role: .destructive) {
                Task { await controller.stop() }
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .keyboardShortcut(.return, modifiers: [])
        case .failed:
            Button("返回") {
                controller.dismissError()
            }
        case .starting:
            ProgressView()
                .controlSize(.small)
        case .stopping:
            ProgressView("正在生成评价…")
                .controlSize(.small)
        case .idle:
            Button("开始面试") {
                Task { await controller.start() }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: [])
            .disabled(
                controller.isImportingResume
                    || controller.isRefreshingEvaluation
            )
        }
    }

    private var recordingStatus: String {
        switch controller.state {
        case .idle:
            if controller.isRefreshingEvaluation {
                controller.evaluationTitle == "简历初评"
                    ? "正在刷新评价和问题"
                    : "正在刷新面试评价"
            } else
            if controller.evaluationTitle == "简历初评",
               controller.evaluation != nil
            {
                "简历初评已生成"
            } else {
                controller.evaluation == nil ? "准备开始" : "面试已结束"
            }
        case .starting:
            "正在启动录音"
        case .recording:
            "正在录音、转写和分析"
        case .stopping:
            "录音已保存，正在整理结论"
        case let .failed(message):
            message
        }
    }

    private var isRecording: Bool {
        if case .recording = controller.state { return true }
        return false
    }

    private var supportedResumeExtensions: Set<String> {
        ["pdf", "doc", "docx", "txt", "png", "jpg", "jpeg"]
    }

    private var supportedResumeTypes: [UTType] {
        let standard: [UTType] = [
            .pdf,
            .plainText,
            .png,
            .jpeg
        ]
        let word = ["doc", "docx"].compactMap {
            UTType(filenameExtension: $0)
        }
        return standard + word
    }

    private func activityIndicator(
        _ label: String,
        active: Bool
    ) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(active ? Color.green : Color.gray.opacity(0.4))
                .frame(width: 9, height: 9)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func updateActivity() async {
        while !Task.isCancelled {
            systemActive = isRecording
                && hub.hasRecentAudio(source: .system, within: 1)
            microphoneActive = isRecording
                && hub.hasRecentAudio(source: .microphone, within: 1)

            try? await Task.sleep(for: .milliseconds(500))
        }
    }
}
