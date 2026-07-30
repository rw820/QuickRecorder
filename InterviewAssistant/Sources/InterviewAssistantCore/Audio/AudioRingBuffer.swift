import Foundation

public struct AudioRingBuffer {
    public let capacitySeconds: TimeInterval
    public private(set) var chunks: [AudioChunk] = []
    private var duration: TimeInterval = 0

    public init(capacitySeconds: TimeInterval) {
        self.capacitySeconds = capacitySeconds
    }

    @discardableResult
    public mutating func append(_ chunk: AudioChunk) -> Int {
        chunks.append(chunk)
        duration += chunk.duration

        var dropped = 0
        while duration > capacitySeconds, !chunks.isEmpty {
            duration -= chunks.removeFirst().duration
            dropped += 1
        }
        return dropped
    }
}
