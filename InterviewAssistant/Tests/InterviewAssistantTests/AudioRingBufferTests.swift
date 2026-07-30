import AVFoundation
import InterviewAssistantCore

enum AudioRingBufferTests {
    static let all = [
        TestCase(name: "音频缓冲超过容量时丢弃最早片段") {
            var buffer = AudioRingBuffer(capacitySeconds: 0.04)
            let format = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: 48_000,
                channels: 1,
                interleaved: false
            )!

            func chunk(_ timestamp: TimeInterval) -> AudioChunk {
                let pcm = AVAudioPCMBuffer(
                    pcmFormat: format,
                    frameCapacity: 960
                )!
                pcm.frameLength = 960
                return AudioChunk(
                    source: .microphone,
                    timestamp: timestamp,
                    buffer: pcm
                )
            }

            try expect(buffer.append(chunk(0.00)) == 0, "第一个片段不应丢弃")
            try expect(buffer.append(chunk(0.02)) == 0, "第二个片段不应丢弃")
            try expect(buffer.append(chunk(0.04)) == 1, "第三个片段应挤出一个")
            try expect(
                buffer.chunks.map(\.timestamp) == [0.02, 0.04],
                "应该保留最近两个片段"
            )
        }
    ]
}
