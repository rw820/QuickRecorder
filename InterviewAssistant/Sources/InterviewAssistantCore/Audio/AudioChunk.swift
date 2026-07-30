import AVFoundation

public struct AudioChunk: @unchecked Sendable {
    public let source: AudioSource
    public let timestamp: TimeInterval
    public let buffer: AVAudioPCMBuffer

    public var duration: TimeInterval {
        Double(buffer.frameLength) / buffer.format.sampleRate
    }

    public init(
        source: AudioSource,
        timestamp: TimeInterval,
        buffer: AVAudioPCMBuffer
    ) {
        self.source = source
        self.timestamp = timestamp
        self.buffer = buffer
    }
}
