@preconcurrency import AVFoundation

public final class SpeechAudioConverter: @unchecked Sendable {
    private final class InputState: @unchecked Sendable {
        var supplied = false
    }

    private let targetFormat: AVAudioFormat
    private var converter: AVAudioConverter?
    private var converterInputFormat: AVAudioFormat?

    public init(targetFormat: AVAudioFormat) {
        self.targetFormat = targetFormat
    }

    public func convert(
        _ buffer: AVAudioPCMBuffer
    ) throws -> AVAudioPCMBuffer? {
        if buffer.format.isEqual(targetFormat) {
            return buffer.ownedCopy()
        }

        if converter == nil
            || converterInputFormat?.isEqual(buffer.format) != true
        {
            guard let next = AVAudioConverter(
                from: buffer.format,
                to: targetFormat
            ) else {
                throw LiveTranscriptionError.audioConversionFailed
            }
            converter = next
            converterInputFormat = buffer.format
        }
        guard let converter else {
            throw LiveTranscriptionError.audioConversionFailed
        }

        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(
            ceil(Double(buffer.frameLength) * ratio) + 64
        )
        guard let output = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: capacity
        ) else {
            throw LiveTranscriptionError.audioConversionFailed
        }

        let inputState = InputState()
        var conversionError: NSError?
        let status = converter.convert(
            to: output,
            error: &conversionError
        ) { _, inputStatus in
            if inputState.supplied {
                inputStatus.pointee = .noDataNow
                return nil
            }
            inputState.supplied = true
            inputStatus.pointee = .haveData
            return buffer
        }

        if status == .error {
            throw conversionError
                ?? LiveTranscriptionError.audioConversionFailed
        }
        return output.frameLength > 0 ? output : nil
    }
}
