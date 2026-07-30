import Combine
import Foundation

public enum RecordingState: Equatable, Sendable {
    case idle
    case starting
    case recording(URL)
    case stopping
    case failed(String)
}

@MainActor
public final class SessionController: ObservableObject {
    @Published public private(set) var state: RecordingState = .idle
    @Published public private(set) var transcript: [TranscriptLine] = []
    @Published public private(set) var partialTranscripts:
        [AudioSource: String] = [:]
    @Published public private(set) var suggestions:
        [InterviewSuggestion] = []
    @Published public private(set) var evaluation: InterviewEvaluation?
    @Published public private(set) var assistantStatus = "准备转写"
    @Published public private(set) var warning: String?
    @Published public private(set) var lastSessionDirectory: URL?
    @Published public private(set) var resume: ResumeDocument?
    @Published public private(set) var resumeStatus = "未导入简历"
    @Published public private(set) var isImportingResume = false
    @Published public private(set) var isRefreshingResumeEvaluation = false
    @Published public private(set) var isRefreshingInterviewEvaluation = false
    @Published public private(set) var evaluationTitle = "本次面试评价"

    public var isRefreshingEvaluation: Bool {
        isRefreshingResumeEvaluation || isRefreshingInterviewEvaluation
    }

    public var canRefreshCurrentEvaluation: Bool {
        guard
            state == .idle,
            evaluation != nil,
            !isRefreshingEvaluation
        else {
            return false
        }
        if evaluationTitle == "简历初评" {
            return resume != nil && resumeService != nil
        }
        return lastSessionDirectory != nil
            && interviewEvaluationRefresher != nil
    }

    private let engine: any RecordingEngine
    private let store: SessionDirectoryStore
    private let resumeService: (any ResumeImportServicing)?
    private let interviewEvaluationRefresher:
        (any InterviewEvaluationRefreshing)?
    private var eventTask: Task<Void, Never>?

    public init(
        engine: any RecordingEngine,
        store: SessionDirectoryStore = SessionDirectoryStore(),
        events: AsyncStream<AssistantEvent>? = nil,
        resumeService: (any ResumeImportServicing)? = nil,
        interviewEvaluationRefresher:
            (any InterviewEvaluationRefreshing)? = nil
    ) {
        self.engine = engine
        self.store = store
        self.resumeService = resumeService
        self.interviewEvaluationRefresher = interviewEvaluationRefresher
        if let events {
            eventTask = Task { [weak self] in
                for await event in events {
                    guard let self else { return }
                    handle(event)
                }
            }
        }
        if resumeService != nil {
            Task { [weak self] in
                await self?.restoreResume()
            }
        }
    }

    public func start() async {
        guard
            state == .idle,
            !isImportingResume,
            !isRefreshingEvaluation
        else {
            return
        }
        transcript = []
        partialTranscripts = [:]
        suggestions = []
        evaluation = nil
        evaluationTitle = "本次面试评价"
        warning = nil
        assistantStatus = "正在启动本机转写"
        state = .starting

        do {
            let directory = try store.createSessionDirectory()
            lastSessionDirectory = directory
            try await engine.start(in: directory)
            state = .recording(directory)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    public func stop() async {
        guard case .recording = state else { return }
        state = .stopping

        do {
            try await engine.stop()
            state = .idle
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    public func dismissError() {
        if case .failed = state {
            state = .idle
        }
    }

    public func importResume(from url: URL) async {
        guard state == .idle, let resumeService else { return }
        isImportingResume = true
        resumeStatus = ["png", "jpg", "jpeg"].contains(
            url.pathExtension.lowercased()
        ) ? "正在识别图片文字" : "正在读取简历"
        warning = nil

        do {
            resumeStatus = "正在生成简历初评"
            let result = try await resumeService.importResume(from: url)
            resume = result.document
            evaluation = result.evaluation
            evaluationTitle = "简历初评"
            resumeStatus = "已导入 \(result.document.originalFileName)"
            warning = result.warning
        } catch {
            warning = error.localizedDescription
            resumeStatus = resume == nil ? "未导入简历" : "保留原简历"
        }
        isImportingResume = false
    }

    public func clearResume() async {
        guard state == .idle, let resumeService else { return }
        do {
            try await resumeService.clear()
            resume = nil
            resumeStatus = "未导入简历"
            if evaluationTitle == "简历初评" {
                evaluation = nil
            }
            warning = nil
        } catch {
            warning = "清除简历失败：\(error.localizedDescription)"
        }
    }

    public func refreshResumeEvaluation(
        customRequirement: String? = nil
    ) async {
        guard
            state == .idle,
            resume != nil,
            !isRefreshingResumeEvaluation,
            let resumeService
        else {
            return
        }
        isRefreshingResumeEvaluation = true
        resumeStatus = "正在刷新评价和问题"
        warning = nil
        defer { isRefreshingResumeEvaluation = false }

        do {
            evaluation = try await resumeService.refreshEvaluation(
                customRequirement: customRequirement
            )
            evaluationTitle = "简历初评"
            resumeStatus = "简历初评已刷新"
        } catch {
            warning = "刷新失败：\(error.localizedDescription)"
            resumeStatus = "保留原简历初评"
        }
    }

    public func refreshCurrentEvaluation(
        customRequirement: String? = nil
    ) async {
        if evaluationTitle == "简历初评" {
            await refreshResumeEvaluation(
                customRequirement: customRequirement
            )
        } else {
            await refreshInterviewEvaluation(
                customRequirement: customRequirement
            )
        }
    }

    public func refreshInterviewEvaluation(
        customRequirement: String? = nil
    ) async {
        guard
            state == .idle,
            evaluationTitle == "本次面试评价",
            evaluation != nil,
            lastSessionDirectory != nil,
            !isRefreshingInterviewEvaluation,
            let interviewEvaluationRefresher
        else {
            return
        }
        isRefreshingInterviewEvaluation = true
        assistantStatus = "正在刷新面试评价"
        warning = nil
        defer { isRefreshingInterviewEvaluation = false }

        do {
            evaluation = try await interviewEvaluationRefresher
                .refreshEvaluation(
                    customRequirement: customRequirement
                )
            assistantStatus = "本次面试评价已刷新"
        } catch {
            warning = "刷新失败：\(error.localizedDescription)"
            assistantStatus = "保留原面试评价"
        }
    }

    private func handle(_ event: AssistantEvent) {
        switch event {
        case let .status(message):
            assistantStatus = message
        case let .transcript(line):
            partialTranscripts[line.source] = nil
            guard !transcript.contains(where: { $0.id == line.id }) else {
                return
            }
            transcript.append(line)
            transcript.sort {
                if $0.startTime == $1.startTime {
                    return $0.source.rawValue < $1.source.rawValue
                }
                return $0.startTime < $1.startTime
            }
        case let .partialTranscript(source, text):
            partialTranscripts[source] = text.isEmpty ? nil : text
        case let .suggestions(next):
            suggestions = Array(next.prefix(3))
        case let .evaluation(next):
            evaluation = next
            evaluationTitle = "本次面试评价"
        case let .warning(message):
            warning = message
        }
    }

    private func restoreResume() async {
        guard let resumeService else { return }
        do {
            guard let result = try await resumeService.restore() else {
                return
            }
            resume = result.document
            resumeStatus = "已导入 \(result.document.originalFileName)"
            if let evaluation = result.evaluation {
                self.evaluation = evaluation
                evaluationTitle = "简历初评"
            }
            warning = result.warning
        } catch {
            warning = "恢复简历失败：\(error.localizedDescription)"
        }
    }
}
