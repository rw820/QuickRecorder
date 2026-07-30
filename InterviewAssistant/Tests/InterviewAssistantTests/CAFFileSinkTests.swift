import AVFoundation
import Foundation
import InterviewAssistantCore

enum CAFFileSinkTests {
    static let all = [
        TestCase(name: "系统声音和麦克风分别保存为 CAF 文件") {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
            let sink = CAFFileSink()
            let format = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: 48_000,
                channels: 1,
                interleaved: false
            )!

            try sink.start(in: directory)
            sink.append(
                AudioChunk(
                    source: .system,
                    timestamp: 0,
                    buffer: makeBuffer(format: format)
                )
            )
            sink.append(
                AudioChunk(
                    source: .microphone,
                    timestamp: 0,
                    buffer: makeBuffer(format: format)
                )
            )
            try sink.finish()

            let system = try AVAudioFile(
                forReading: directory.appendingPathComponent("system.caf")
            )
            let microphone = try AVAudioFile(
                forReading: directory.appendingPathComponent("microphone.caf")
            )
            try expect(system.length == 480, "系统声音文件应包含 480 帧")
            try expect(microphone.length == 480, "麦克风文件应包含 480 帧")
        }
    ]

    private static func makeBuffer(
        format: AVAudioFormat
    ) -> AVAudioPCMBuffer {
        let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: 480
        )!
        buffer.frameLength = 480
        return buffer
    }
}
