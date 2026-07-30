import AVFoundation
import InterviewAssistantCore

enum SpeechAudioConverterTests {
    static let all = [
        TestCase(name: "转写音频格式变化时可以安全重采样") {
            let target = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: 16_000,
                channels: 1,
                interleaved: false
            )!
            let stereo48 = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: 48_000,
                channels: 2,
                interleaved: false
            )!
            let mono44 = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: 44_100,
                channels: 1,
                interleaved: false
            )!
            let converter = SpeechAudioConverter(targetFormat: target)

            let first = try converter.convert(
                makeBuffer(format: stereo48, frames: 960)
            )
            let second = try converter.convert(
                makeBuffer(format: mono44, frames: 882)
            )

            try expect(first?.format == target, "第一种格式应转换成功")
            try expect(second?.format == target, "格式变化后应重建转换器")
            try expect(first?.frameLength ?? 0 > 0, "第一段不应为空")
            try expect(second?.frameLength ?? 0 > 0, "第二段不应为空")
        }
    ]

    private static func makeBuffer(
        format: AVAudioFormat,
        frames: AVAudioFrameCount
    ) -> AVAudioPCMBuffer {
        let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: frames
        )!
        buffer.frameLength = frames
        return buffer
    }
}
