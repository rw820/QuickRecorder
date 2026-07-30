import Foundation

public enum LiveInterviewRecorderError: LocalizedError {
    case alreadyRunning

    public var errorDescription: String? {
        switch self {
        case .alreadyRunning:
            "录音已经开始"
        }
    }
}

public final class LiveInterviewRecorder:
    RecordingEngine,
    @unchecked Sendable
{
    public let hub: AudioTapHub

    private let sources: [any AudioCaptureSource]
    private let sink: any AudioFileSink
    private let lock = NSLock()
    private var isRunning = false

    public init(
        sources: [any AudioCaptureSource],
        sink: any AudioFileSink,
        hub: AudioTapHub = AudioTapHub()
    ) {
        self.sources = sources
        self.sink = sink
        self.hub = hub
    }

    public func start(in directory: URL) async throws {
        let canStart = lock.withLock {
            guard !isRunning else { return false }
            isRunning = true
            return true
        }
        guard canStart else {
            throw LiveInterviewRecorderError.alreadyRunning
        }

        do {
            try sink.start(in: directory)
            var startedSources: [any AudioCaptureSource] = []
            do {
                for source in sources {
                    try await source.start { [hub, sink] chunk in
                        _ = hub.ingest(chunk)
                        sink.append(chunk)
                    }
                    startedSources.append(source)
                }
            } catch {
                for source in startedSources.reversed() {
                    await source.stop()
                }
                try? sink.finish()
                throw error
            }
        } catch {
            lock.withLock { isRunning = false }
            throw error
        }
    }

    public func stop() async throws {
        let shouldStop = lock.withLock {
            guard isRunning else { return false }
            isRunning = false
            return true
        }
        guard shouldStop else { return }

        for source in sources.reversed() {
            await source.stop()
        }
        try sink.finish()
    }
}
