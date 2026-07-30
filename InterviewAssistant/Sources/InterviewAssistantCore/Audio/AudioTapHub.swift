import Foundation

public final class AudioTapHub: @unchecked Sendable {
    public let stream: AsyncStream<AudioChunk>

    private let continuation: AsyncStream<AudioChunk>.Continuation
    private let lock = NSLock()
    private let capacitySeconds: TimeInterval
    private var buffers: [AudioSource: AudioRingBuffer]
    private var lastArrival: [AudioSource: TimeInterval] = [:]

    public init(capacitySeconds: TimeInterval = 30) {
        let pair = AsyncStream.makeStream(
            of: AudioChunk.self,
            bufferingPolicy: .bufferingNewest(1_500)
        )
        self.capacitySeconds = capacitySeconds
        stream = pair.stream
        continuation = pair.continuation
        buffers = [
            .system: AudioRingBuffer(capacitySeconds: capacitySeconds),
            .microphone: AudioRingBuffer(capacitySeconds: capacitySeconds)
        ]
    }

    @discardableResult
    public func ingest(_ chunk: AudioChunk) -> Int {
        let dropped = lock.withLock {
            lastArrival[chunk.source] = ProcessInfo.processInfo.systemUptime
            return buffers[
                chunk.source,
                default: AudioRingBuffer(capacitySeconds: capacitySeconds)
            ].append(chunk)
        }
        continuation.yield(chunk)
        return dropped
    }

    public func snapshot(source: AudioSource) -> [AudioChunk] {
        lock.withLock {
            buffers[source]?.chunks ?? []
        }
    }

    public func hasRecentAudio(
        source: AudioSource,
        within interval: TimeInterval
    ) -> Bool {
        lock.withLock {
            guard let arrival = lastArrival[source] else { return false }
            return ProcessInfo.processInfo.systemUptime - arrival <= interval
        }
    }
}
