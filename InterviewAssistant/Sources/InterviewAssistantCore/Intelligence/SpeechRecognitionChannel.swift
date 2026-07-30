@preconcurrency import AVFoundation
import CoreMedia
import Foundation
import Speech

@available(macOS 26.0, *)
actor SpeechRecognitionChannel {
    typealias LineHandler = @Sendable (TranscriptLine) -> Void
    typealias PartialHandler = @Sendable (String) -> Void
    typealias WarningHandler = @Sendable (String) -> Void

    private let source: AudioSource
    private let lineHandler: LineHandler
    private let partialHandler: PartialHandler
    private let warningHandler: WarningHandler

    private var analyzer: SpeechAnalyzer?
    private var continuation:
        AsyncStream<AnalyzerInput>.Continuation?
    private var analysisTask: Task<Void, Never>?
    private var resultTask: Task<Void, Never>?
    private var audioConverter: SpeechAudioConverter?
    private var lastSignature = ""
    private var started = false
    private var timelineOffset: TimeInterval = 0
    private var pendingText = ""
    private var pendingStart: TimeInterval?
    private var pendingEnd: TimeInterval = 0

    init(
        source: AudioSource,
        lineHandler: @escaping LineHandler,
        partialHandler: @escaping PartialHandler,
        warningHandler: @escaping WarningHandler
    ) {
        self.source = source
        self.lineHandler = lineHandler
        self.partialHandler = partialHandler
        self.warningHandler = warningHandler
    }

    func ingest(
        _ buffer: AVAudioPCMBuffer,
        startTime: TimeInterval
    ) async throws {
        if !started {
            timelineOffset = max(0, startTime)
            try await start(inputFormat: buffer.format)
        }

        guard let converted = try audioConverter?.convert(buffer) else {
            return
        }
        continuation?.yield(
            AnalyzerInput(buffer: converted)
        )
    }

    func finish() async {
        continuation?.finish()
        continuation = nil
        await analysisTask?.value
        if let analyzer {
            do {
                try await analyzer.finalizeAndFinishThroughEndOfInput()
            } catch {
                warningHandler("本机转写收尾失败：\(error.localizedDescription)")
            }
        }
        await resultTask?.value
        partialHandler("")
        flushPending()
        analysisTask = nil
        resultTask = nil
        analyzer = nil
    }

    private func start(inputFormat: AVAudioFormat) async throws {
        let requestedLocale = Locale(identifier: "zh-CN")
        guard let locale = await SpeechTranscriber.supportedLocale(
            equivalentTo: requestedLocale
        ) else {
            throw LiveTranscriptionError.unsupportedLocale
        }

        let transcriber = SpeechTranscriber(
            locale: locale,
            preset: .timeIndexedProgressiveTranscription
        )
        let modules: [any SpeechModule] = [transcriber]

        let status = await AssetInventory.status(forModules: modules)
        if status != .installed {
            if let request = try await AssetInventory
                .assetInstallationRequest(supporting: modules)
            {
                warningHandler("首次使用正在准备本机普通话识别模型")
                try await request.downloadAndInstall()
            }
        }
        _ = try? await AssetInventory.reserve(locale: locale)

        let format = await SpeechAnalyzer.bestAvailableAudioFormat(
            compatibleWith: modules,
            considering: inputFormat
        ) ?? inputFormat
        audioConverter = SpeechAudioConverter(targetFormat: format)

        let pair = AsyncStream.makeStream(
            of: AnalyzerInput.self,
            bufferingPolicy: .bufferingNewest(2_000)
        )
        continuation = pair.continuation

        let analyzer = SpeechAnalyzer(modules: modules)
        self.analyzer = analyzer
        try await analyzer.prepareToAnalyze(in: format)

        analysisTask = Task {
            do {
                try await analyzer.start(inputSequence: pair.stream)
            } catch {
                self.warningHandler(
                    "本机转写中断：\(error.localizedDescription)"
                )
            }
        }
        resultTask = Task {
            do {
                for try await result in transcriber.results {
                    if result.isFinal {
                        self.partialHandler("")
                        self.publish(result)
                    } else {
                        self.partialHandler(
                            String(result.text.characters)
                                .trimmingCharacters(
                                    in: .whitespacesAndNewlines
                                )
                        )
                    }
                }
            } catch {
                self.partialHandler("")
                self.warningHandler(
                    "本机转写结果读取失败：\(error.localizedDescription)"
                )
            }
        }
        started = true
    }

    private func publish(_ result: SpeechTranscriber.Result) {
        let text = String(result.text.characters)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let start = max(
            0,
            timelineOffset + result.range.start.seconds
        )
        let end = max(
            start,
            timelineOffset + CMTimeRangeGetEnd(result.range).seconds
        )
        if let pendingStart, start - pendingEnd <= 1.2 {
            pendingText += text
            pendingEnd = end
            self.pendingStart = pendingStart
        } else {
            flushPending()
            pendingText = text
            pendingStart = start
            pendingEnd = end
        }

        if pendingText.count >= 50
            || pendingText.contains(where: "。！？?!".contains)
        {
            flushPending()
        }
    }

    private func flushPending() {
        guard
            let start = pendingStart,
            !pendingText.isEmpty
        else {
            return
        }
        let text = pendingText
        let end = pendingEnd
        pendingText = ""
        pendingStart = nil
        pendingEnd = 0

        let signature = "\(start)|\(end)|\(text)"
        guard signature != lastSignature else { return }
        lastSignature = signature

        lineHandler(
            TranscriptLine(
                source: source,
                startTime: start,
                endTime: end,
                text: text
            )
        )
    }

}

public enum LiveTranscriptionError: LocalizedError {
    case unsupportedSystem
    case unsupportedLocale
    case audioConversionFailed

    public var errorDescription: String? {
        switch self {
        case .unsupportedSystem:
            "实时转写需要 macOS 26 或更高版本"
        case .unsupportedLocale:
            "当前系统没有可用的普通话本机识别模型"
        case .audioConversionFailed:
            "无法转换实时识别所需的音频格式"
        }
    }
}
