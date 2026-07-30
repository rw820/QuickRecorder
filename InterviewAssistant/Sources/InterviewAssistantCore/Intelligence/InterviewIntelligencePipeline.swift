import Foundation

public actor InterviewIntelligencePipeline {
    public typealias ProviderFactory =
        @Sendable (URL) throws -> any InterviewAnalysisProvider

    public nonisolated let events: AsyncStream<AssistantEvent>

    private let hub: AudioTapHub
    private let providerFactory: ProviderFactory
    private let resumeStore: CurrentResumeStore
    private let continuation: AsyncStream<AssistantEvent>.Continuation

    private var provider: (any InterviewAnalysisProvider)?
    private var store: TranscriptStore?
    private var directory: URL?
    private var transcript: [TranscriptLine] = []
    private var lastSuggestionTime: TimeInterval?
    private var suggestionTask: Task<Void, Never>?
    private var transcriptionFinish: (@Sendable () async -> Void)?
    private var warningText: String?
    private var currentResume: ResumeDocument?

    public init(
        hub: AudioTapHub,
        providerFactory: @escaping ProviderFactory,
        resumeStore: CurrentResumeStore = CurrentResumeStore()
    ) {
        let pair = AsyncStream.makeStream(
            of: AssistantEvent.self,
            bufferingPolicy: .bufferingNewest(500)
        )
        events = pair.stream
        continuation = pair.continuation
        self.hub = hub
        self.providerFactory = providerFactory
        self.resumeStore = resumeStore
    }

    public func start(in directory: URL) async throws {
        self.directory = directory
        transcript = []
        lastSuggestionTime = nil
        suggestionTask = nil
        warningText = nil
        currentResume = nil
        store = try TranscriptStore(directory: directory)
        try Data().write(
            to: directory.appendingPathComponent("suggestions.jsonl"),
            options: .atomic
        )

        do {
            currentResume = try resumeStore.load()
            if currentResume != nil {
                try resumeStore.copyArtifacts(to: directory)
            }
        } catch {
            warn("当前简历读取失败：\(error.localizedDescription)")
        }

        do {
            provider = try providerFactory(directory)
        } catch {
            provider = nil
            warn("Codex 暂不可用：\(error.localizedDescription)")
        }

        if #available(macOS 26.0, *) {
            let service = LiveTranscriptionService(
                hub: hub,
                eventHandler: { [weak self] event in
                    Task { await self?.receive(event) }
                }
            )
            await service.start()
            transcriptionFinish = {
                await service.finish()
            }
        } else {
            warn("当前系统不支持本机实时转写，录音仍会正常保存")
        }
    }

    public func accept(_ line: TranscriptLine) {
        guard !transcript.contains(where: { $0.id == line.id }) else {
            return
        }
        transcript.append(line)
        do {
            try store?.append(line)
        } catch {
            warn("逐字稿保存失败：\(error.localizedDescription)")
        }
        continuation.yield(.transcript(line))

        guard
            line.source == .system,
            line.text.count >= 8,
            provider != nil,
            suggestionTask == nil
        else {
            return
        }

        if let lastSuggestionTime,
           line.endTime - lastSuggestionTime < 15
        {
            return
        }
        lastSuggestionTime = line.endTime

        let recentStart = max(0, line.endTime - 180)
        let recent = transcript.filter { $0.endTime >= recentStart }
        suggestionTask = Task {
            await self.generateSuggestions(from: recent)
        }
    }

    public func finish() async {
        if let transcriptionFinish {
            await transcriptionFinish()
            self.transcriptionFinish = nil
            await Task.yield()
        }

        if let suggestionTask {
            await suggestionTask.value
        }
        suggestionTask = nil

        do {
            try store?.finish()
        } catch {
            warn("逐字稿保存失败：\(error.localizedDescription)")
        }

        let evaluation: InterviewEvaluation
        if transcript.isEmpty {
            evaluation = fallbackEvaluation(
                reason: "没有识别到有效逐字稿"
            )
            warn("没有识别到有效逐字稿，已保留原始录音")
        } else if let provider {
            continuation.yield(.status("正在生成最终评价"))
            do {
                evaluation = try await provider.generateEvaluation(
                    from: transcript,
                    resumeText: currentResume?.text
                )
            } catch {
                warn("最终评价生成失败：\(error.localizedDescription)")
                evaluation = fallbackEvaluation(
                    reason: "Codex 分析失败，详细判断待确认"
                )
            }
        } else {
            evaluation = fallbackEvaluation(
                reason: "Codex 未连接，详细判断待确认"
            )
        }

        save(evaluation)
        continuation.yield(.evaluation(evaluation))
        continuation.yield(.status("本次面试评价已生成"))
    }

    public func cancel() async {
        suggestionTask?.cancel()
        suggestionTask = nil
        if let transcriptionFinish {
            await transcriptionFinish()
            self.transcriptionFinish = nil
        }
        try? store?.finish()
    }

    public func latestWarning() -> String? {
        warningText
    }

    private func receive(_ event: AssistantEvent) {
        switch event {
        case let .transcript(line):
            accept(line)
        case let .warning(message):
            warn(message)
        default:
            continuation.yield(event)
        }
    }

    private func generateSuggestions(
        from lines: [TranscriptLine]
    ) async {
        guard let provider else {
            suggestionTask = nil
            return
        }
        continuation.yield(.status("正在生成追问建议"))
        do {
            let suggestions = try await suggestionsWithTimeoutRetry(
                provider: provider,
                lines: lines
            )
            try appendSuggestions(suggestions)
            continuation.yield(.suggestions(suggestions))
            continuation.yield(.status("正在本机实时转写"))
        } catch {
            warn("追问建议生成失败：\(error.localizedDescription)")
        }
        suggestionTask = nil
    }

    private func suggestionsWithTimeoutRetry(
        provider: any InterviewAnalysisProvider,
        lines: [TranscriptLine]
    ) async throws -> [InterviewSuggestion] {
        do {
            return try await provider.generateSuggestions(
                from: lines,
                resumeText: currentResume?.text
            )
        } catch CodexCLIProviderError.timedOut {
            continuation.yield(.status("追问生成较慢，正在重试"))
            return try await provider.generateSuggestions(
                from: lines,
                resumeText: currentResume?.text
            )
        }
    }

    private func appendSuggestions(
        _ suggestions: [InterviewSuggestion]
    ) throws {
        guard let directory else { return }
        let url = directory.appendingPathComponent("suggestions.jsonl")
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        let encoder = JSONEncoder()
        for suggestion in suggestions.prefix(3) {
            var data = try encoder.encode(suggestion)
            data.append(0x0A)
            try handle.write(contentsOf: data)
        }
    }

    private func save(_ evaluation: InterviewEvaluation) {
        guard let directory else { return }
        do {
            try evaluation.markdown.write(
                to: directory.appendingPathComponent(
                    "evaluation-report.md"
                ),
                atomically: true,
                encoding: .utf8
            )
        } catch {
            warn("评价文件保存失败：\(error.localizedDescription)")
        }
    }

    private func fallbackEvaluation(
        reason: String
    ) -> InterviewEvaluation {
        InterviewEvaluation(
            markdown: """
            ## 总评
            \(reason)。

            ## 优势
            - 待确认。

            ## 劣势
            - 待确认。

            ## 风险
            - 请结合原始录音复核，当前证据不足。
            """
        )
    }

    private func warn(_ message: String) {
        warningText = message
        continuation.yield(.warning(message))
    }
}
