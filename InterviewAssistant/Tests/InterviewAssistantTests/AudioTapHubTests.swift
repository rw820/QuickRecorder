import AVFoundation
import InterviewAssistantCore

enum AudioTapHubTests {
    static let all = [
        TestCase(name: "音频片段会同时发布并保留在缓冲中") {
            let hub = AudioTapHub(capacitySeconds: 30)
            let format = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: 48_000,
                channels: 1,
                interleaved: false
            )!
            let pcm = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: 480
            )!
            pcm.frameLength = 480
            let chunk = AudioChunk(
                source: .microphone,
                timestamp: 1,
                buffer: pcm
            )

            let next = Task {
                var iterator = hub.stream.makeAsyncIterator()
                return await iterator.next()
            }
            await Task.yield()
            try expect(hub.ingest(chunk) == 0, "容量足够时不应丢弃")
            let published = await next.value

            try expect(published?.timestamp == 1, "应该发布刚收到的片段")
            try expect(
                hub.snapshot(source: .microphone).count == 1,
                "应该在麦克风缓冲里保留片段"
            )
        },
        TestCase(name: "缓冲区满后仍能判断最近收到声音") {
            let hub = AudioTapHub(capacitySeconds: 0.02)
            let format = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: 48_000,
                channels: 1,
                interleaved: false
            )!
            let pcm = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: 480
            )!
            pcm.frameLength = 480
            for index in 0..<20 {
                hub.ingest(
                    AudioChunk(
                        source: .microphone,
                        timestamp: Double(index) / 100,
                        buffer: pcm
                    )
                )
            }
            try expect(
                hub.hasRecentAudio(source: .microphone, within: 1),
                "缓冲区满后最近声音仍应显示活跃"
            )
        }
    ]
}
