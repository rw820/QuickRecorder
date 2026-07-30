import Foundation

public protocol AudioCaptureSource: Sendable {
    var source: AudioSource { get }

    func start(
        handler: @escaping @Sendable (AudioChunk) -> Void
    ) async throws

    func stop() async
}

public protocol AudioFileSink: Sendable {
    func start(in directory: URL) throws
    func append(_ chunk: AudioChunk)
    func finish() throws
}
