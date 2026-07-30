import Foundation

@available(macOS 26.0, *)
public actor LiveTranscriptionService {
    public typealias EventHandler = @Sendable (AssistantEvent) -> Void

    private let hub: AudioTapHub
    private let eventHandler: EventHandler
    private var channels: [AudioSource: SpeechRecognitionChannel] = [:]
    private var consumeTask: Task<Void, Never>?
    private var sessionStart: TimeInterval?

    public init(
        hub: AudioTapHub,
        eventHandler: @escaping EventHandler
    ) {
        self.hub = hub
        self.eventHandler = eventHandler
    }

    public func start() {
        guard consumeTask == nil else { return }
        eventHandler(.status("正在本机实时转写"))
        consumeTask = Task {
            for await chunk in hub.stream {
                guard !Task.isCancelled else { break }
                await self.route(chunk)
            }
        }
    }

    public func finish() async {
        consumeTask?.cancel()
        consumeTask = nil

        for channel in channels.values {
            await channel.finish()
        }
        channels.removeAll()

    }

    private func route(_ chunk: AudioChunk) async {
        if sessionStart == nil {
            sessionStart = chunk.timestamp
        }
        let relativeTime = max(
            0,
            chunk.timestamp - (sessionStart ?? chunk.timestamp)
        )

        let channel: SpeechRecognitionChannel
        if let existing = channels[chunk.source] {
            channel = existing
        } else {
            channel = SpeechRecognitionChannel(
                source: chunk.source,
                lineHandler: { [eventHandler] line in
                    eventHandler(.transcript(line))
                },
                partialHandler: { [eventHandler, source = chunk.source] text in
                    eventHandler(
                        .partialTranscript(source: source, text: text)
                    )
                },
                warningHandler: { [eventHandler] message in
                    eventHandler(.warning(message))
                }
            )
            channels[chunk.source] = channel
        }

        do {
            try await channel.ingest(
                chunk.buffer,
                startTime: relativeTime
            )
        } catch {
            let sourceName = chunk.source == .system
                ? "候选人"
                : "面试官"
            eventHandler(
                .warning(
                    "\(sourceName)转写失败：\(error.localizedDescription)"
                )
            )
        }
    }
}
