import AppKit
import InterviewAssistantCore
import SwiftUI

struct HistoryBrowserView: View {
    let store: InterviewHistoryStore

    @Environment(\.dismiss) private var dismiss
    @State private var records: [InterviewHistoryRecord] = []
    @State private var selectedID: InterviewHistoryRecord.ID?
    @State private var searchText = ""
    @State private var detailSection = DetailSection.evaluation
    @State private var isLoading = true
    @State private var openError: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("历史记录")
                    .font(.title2.bold())
                Spacer()
                Button("完成") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(18)

            Divider()

            if isLoading {
                ProgressView("正在读取历史记录…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if records.isEmpty {
                ContentUnavailableView(
                    "暂无历史记录",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("完成一次面试后，记录会显示在这里")
                )
            } else {
                browser
            }
        }
        .frame(minWidth: 920, minHeight: 620)
        .task {
            let loaded = await Task.detached {
                store.load()
            }.value
            records = loaded
            selectedID = loaded.first?.id
            isLoading = false
        }
        .onChange(of: searchText) {
            guard
                let selectedID,
                filteredRecords.contains(where: { $0.id == selectedID })
            else {
                self.selectedID = filteredRecords.first?.id
                return
            }
        }
        .alert(
            "无法打开",
            isPresented: Binding(
                get: { openError != nil },
                set: { visible in
                    if !visible {
                        openError = nil
                    }
                }
            )
        ) {
            Button("好", role: .cancel) {}
        } message: {
            Text(openError ?? "请稍后重试")
        }
    }

    private var browser: some View {
        HSplitView {
            historyList
                .frame(minWidth: 280, idealWidth: 310, maxWidth: 360)
            detail
                .frame(minWidth: 560, maxWidth: .infinity)
        }
    }

    private var historyList: some View {
        VStack(spacing: 10) {
            TextField("搜索姓名、评价或逐字稿", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 14)
                .padding(.top, 14)

            if filteredRecords.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                List(filteredRecords, selection: $selectedID) { record in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(record.displayName)
                            .font(.body.bold())
                            .lineLimit(2)
                        Text(record.dateText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 5)
                    .tag(record.id)
                }
                .listStyle(.sidebar)
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let record = selectedRecord {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(record.displayName)
                        .font(.title3.bold())
                        .lineLimit(2)
                    Text(record.dateText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(18)

                Picker("内容", selection: $detailSection) {
                    ForEach(DetailSection.allCases) { section in
                        Text(section.rawValue).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(.horizontal, 18)
                .padding(.bottom, 14)

                Divider()

                switch detailSection {
                case .evaluation:
                    textDetail(record.evaluation)
                case .transcript:
                    textDetail(record.transcript)
                case .recordings:
                    recordingDetail(record)
                }
            }
        } else {
            ContentUnavailableView(
                "请选择一条记录",
                systemImage: "doc.text.magnifyingglass"
            )
        }
    }

    private func textDetail(_ text: String?) -> some View {
        ScrollView {
            Text(text ?? "未记录")
                .foregroundStyle(text == nil ? .secondary : .primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
        }
    }

    private func recordingDetail(
        _ record: InterviewHistoryRecord
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            recordingRow(
                title: "候选人录音",
                icon: "speaker.wave.2.fill",
                url: record.systemAudioURL
            )
            recordingRow(
                title: "面试官录音",
                icon: "mic.fill",
                url: record.microphoneAudioURL
            )

            Divider()

            Button {
                open(record.directory, message: "无法打开场次文件夹")
            } label: {
                Label("打开文件夹", systemImage: "folder")
            }

            Spacer()
        }
        .padding(20)
    }

    private func recordingRow(
        title: String,
        icon: String,
        url: URL?
    ) -> some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            if let url {
                Button("播放") {
                    open(url, message: "无法打开\(title)")
                }
            } else {
                Text("未记录")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(
            Color.primary.opacity(0.045),
            in: RoundedRectangle(cornerRadius: 10)
        )
    }

    private var filteredRecords: [InterviewHistoryRecord] {
        records.filter { $0.matches(searchText) }
    }

    private var selectedRecord: InterviewHistoryRecord? {
        guard let selectedID else { return filteredRecords.first }
        return filteredRecords.first { $0.id == selectedID }
    }

    private func open(_ url: URL, message: String) {
        guard NSWorkspace.shared.open(url) else {
            openError = message
            return
        }
    }
}

private enum DetailSection: String, CaseIterable, Identifiable {
    case evaluation = "评价"
    case transcript = "逐字稿"
    case recordings = "录音"

    var id: Self { self }
}
