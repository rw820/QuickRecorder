import AVFoundation
import Foundation
import InterviewAssistantCore

private final class CaptureSourceSpy:
    AudioCaptureSource,
    @unchecked Sendable
{
    let source: AudioSource
    private let lock = NSLock()
    private var handler: (@Sendable (AudioChunk) -> Void)?
    private var startCount = 0
    private var stopCount = 0

    init(source: AudioSource) {
        self.source = source
    }

    func start(
        handler: @escaping @Sendable (AudioChunk) -> Void
    ) async throws {
        lock.withLock {
            startCount += 1
            self.handler = handler
        }
    }

    func stop() async {
        lock.withLock {
            stopCount += 1
            handler = nil
        }
    }

    func emit(_ chunk: AudioChunk) {
        let current = lock.withLock { handler }
        current?(chunk)
    }

    func counts() -> (starts: Int, stops: Int) {
        lock.withLock { (startCount, stopCount) }
    }
}

private final class AudioFileSinkSpy:
    AudioFileSink,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var received: [AudioSource: Int] = [:]
    private var starts = 0
    private var finishes = 0

    func start(in directory: URL) throws {
        lock.withLock { starts += 1 }
    }

    func append(_ chunk: AudioChunk) {
        lock.withLock {
            received[chunk.source, default: 0] += 1
        }
    }

    func finish() throws {
        lock.withLock { finishes += 1 }
    }

    func snapshot() -> (
        system: Int,
        microphone: Int,
        starts: Int,
        finishes: Int
    ) {
        lock.withLock {
            (
                received[.system, default: 0],
                received[.microphone, default: 0],
                starts,
                finishes
            )
        }
    }
}

enum LiveInterviewRecorderTests {
    static let all = [
        TestCase(name: "每个音频片段同时进入缓冲和文件保存器") {
            let system = CaptureSourceSpy(source: .system)
            let microphone = CaptureSourceSpy(source: .microphone)
            let sink = AudioFileSinkSpy()
            let hub = AudioTapHub()
            let recorder = LiveInterviewRecorder(
                sources: [system, microphone],
                sink: sink,
                hub: hub
            )
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)

            try await recorder.start(in: directory)
            microphone.emit(
                AudioChunk(
                    source: .microphone,
                    timestamp: 0,
                    buffer: makePCMBuffer()
                )
            )
            system.emit(
                AudioChunk(
                    source: .system,
                    timestamp: 0,
                    buffer: makePCMBuffer()
                )
            )

            try expect(
                hub.snapshot(source: .microphone).count == 1,
                "麦克风片段应该进入缓冲"
            )
            try expect(
                hub.snapshot(source: .system).count == 1,
                "系统声音片段应该进入缓冲"
            )
            let beforeStop = sink.snapshot()
            try expect(
                beforeStop.microphone == 1 && beforeStop.system == 1,
                "两路片段都应该写入文件保存器"
            )

            try await recorder.stop()
            try expect(system.counts().stops == 1, "系统声音应该停止一次")
            try expect(
                microphone.counts().stops == 1,
                "麦克风应该停止一次"
            )
            try expect(sink.snapshot().finishes == 1, "文件应该完成保存")
        }
    ]

    private static func makePCMBuffer() -> AVAudioPCMBuffer {
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48_000,
            channels: 1,
            interleaved: false
        )!
        let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: 480
        )!
        buffer.frameLength = 480
        return buffer
    }
}
