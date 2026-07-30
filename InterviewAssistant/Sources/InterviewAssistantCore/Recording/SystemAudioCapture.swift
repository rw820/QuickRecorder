@preconcurrency import AVFoundation
import CoreGraphics
import CoreMedia
import Foundation
@preconcurrency import ScreenCaptureKit

public enum SystemAudioCaptureError: LocalizedError {
    case permissionDenied
    case noDisplay
    case alreadyRunning

    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "没有屏幕录制权限，请在系统设置中允许面试助手录制系统声音"
        case .noDisplay:
            "没有找到可录制的显示器"
        case .alreadyRunning:
            "系统声音录制已经开始"
        }
    }
}

public final class SystemAudioCapture:
    NSObject,
    AudioCaptureSource,
    SCStreamOutput,
    SCStreamDelegate,
    @unchecked Sendable
{
    public let source = AudioSource.system

    private let callbackQueue = DispatchQueue(
        label: "local.ben.InterviewAssistant.system-audio"
    )
    private let lock = NSLock()
    private var handler: (@Sendable (AudioChunk) -> Void)?
    private var captureStream: SCStream?

    public override init() {
        super.init()
    }

    public func start(
        handler: @escaping @Sendable (AudioChunk) -> Void
    ) async throws {
        let canStart = lock.withLock { captureStream == nil }
        guard canStart else {
            throw SystemAudioCaptureError.alreadyRunning
        }

        guard
            CGPreflightScreenCaptureAccess()
                || CGRequestScreenCaptureAccess()
        else {
            throw SystemAudioCaptureError.permissionDenied
        }

        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )
        guard let display = content.displays.first else {
            throw SystemAudioCaptureError.noDisplay
        }

        let filter = SCContentFilter(
            display: display,
            excludingApplications: [],
            exceptingWindows: []
        )
        let configuration = SCStreamConfiguration()
        configuration.width = 2
        configuration.height = 2
        configuration.capturesAudio = true
        configuration.excludesCurrentProcessAudio = true
        configuration.sampleRate = 48_000
        configuration.channelCount = 2

        let stream = SCStream(
            filter: filter,
            configuration: configuration,
            delegate: self
        )
        try stream.addStreamOutput(
            self,
            type: .audio,
            sampleHandlerQueue: callbackQueue
        )
        lock.withLock {
            self.handler = handler
            captureStream = stream
        }

        do {
            try await stream.startCapture()
        } catch {
            lock.withLock {
                self.handler = nil
                captureStream = nil
            }
            try? stream.removeStreamOutput(self, type: .audio)
            throw error
        }
    }

    public func stop() async {
        let stream = lock.withLock {
            let current = captureStream
            captureStream = nil
            handler = nil
            return current
        }
        guard let stream else { return }

        try? await stream.stopCapture()
        try? stream.removeStreamOutput(self, type: .audio)
    }

    public func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of outputType: SCStreamOutputType
    ) {
        guard
            outputType == .audio,
            sampleBuffer.isValid,
            let buffer = sampleBuffer.ownedPCMBuffer
        else {
            return
        }
        let currentHandler = lock.withLock { handler }
        currentHandler?(
            AudioChunk(
                source: .system,
                timestamp: sampleBuffer.presentationTimeStamp.seconds,
                buffer: buffer
            )
        )
    }

    public func stream(
        _ stream: SCStream,
        didStopWithError error: any Error
    ) {
        lock.withLock {
            captureStream = nil
            handler = nil
        }
    }
}
