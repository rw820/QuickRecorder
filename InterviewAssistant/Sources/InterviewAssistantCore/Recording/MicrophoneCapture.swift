@preconcurrency import AVFoundation
import Foundation

public enum MicrophoneCaptureError: LocalizedError {
    case permissionDenied
    case invalidFormat
    case alreadyRunning

    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "没有麦克风权限，请在系统设置中允许面试助手使用麦克风"
        case .invalidFormat:
            "当前麦克风没有可用的音频格式"
        case .alreadyRunning:
            "麦克风录音已经开始"
        }
    }
}

public final class MicrophoneCapture:
    AudioCaptureSource,
    @unchecked Sendable
{
    public let source = AudioSource.microphone

    private let engine: AVAudioEngine
    private let lock = NSLock()
    private var isRunning = false

    public init(engine: AVAudioEngine = AVAudioEngine()) {
        self.engine = engine
    }

    public func start(
        handler: @escaping @Sendable (AudioChunk) -> Void
    ) async throws {
        let canStart = lock.withLock {
            guard !isRunning else { return false }
            isRunning = true
            return true
        }
        guard canStart else {
            throw MicrophoneCaptureError.alreadyRunning
        }

        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        guard granted else {
            lock.withLock { isRunning = false }
            throw MicrophoneCaptureError.permissionDenied
        }

        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            lock.withLock { isRunning = false }
            throw MicrophoneCaptureError.invalidFormat
        }

        input.installTap(
            onBus: 0,
            bufferSize: 960,
            format: format
        ) { buffer, time in
            guard let owned = buffer.ownedCopy() else { return }
            let timestamp = time.isHostTimeValid
                ? AVAudioTime.seconds(forHostTime: time.hostTime)
                : ProcessInfo.processInfo.systemUptime
            handler(
                AudioChunk(
                    source: .microphone,
                    timestamp: timestamp,
                    buffer: owned
                )
            )
        }

        do {
            engine.prepare()
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            lock.withLock { isRunning = false }
            throw error
        }
    }

    public func stop() async {
        let shouldStop = lock.withLock {
            guard isRunning else { return false }
            isRunning = false
            return true
        }
        guard shouldStop else { return }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }
}
