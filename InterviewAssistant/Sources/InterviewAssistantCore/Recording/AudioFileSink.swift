import AVFoundation
import Foundation

public final class CAFFileSink: AudioFileSink, @unchecked Sendable {
    private let queue = DispatchQueue(
        label: "local.ben.InterviewAssistant.audio-file-sink"
    )
    private var directory: URL?
    private var files: [AudioSource: AVAudioFile] = [:]
    private var firstError: (any Error)?

    public init() {}

    public func start(in directory: URL) throws {
        try queue.sync {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            self.directory = directory
            files.removeAll()
            firstError = nil
        }
    }

    public func append(_ chunk: AudioChunk) {
        queue.async { [self] in
            guard firstError == nil, let directory else { return }

            do {
                let file: AVAudioFile
                if let existing = files[chunk.source] {
                    file = existing
                } else {
                    let url = directory.appendingPathComponent(
                        chunk.source == .system
                            ? "system.caf"
                            : "microphone.caf"
                    )
                    file = try AVAudioFile(
                        forWriting: url,
                        settings: chunk.buffer.format.settings,
                        commonFormat: chunk.buffer.format.commonFormat,
                        interleaved: chunk.buffer.format.isInterleaved
                    )
                    files[chunk.source] = file
                }
                try file.write(from: chunk.buffer)
            } catch {
                firstError = error
            }
        }
    }

    public func finish() throws {
        try queue.sync {
            files.removeAll()
            directory = nil
            if let firstError {
                self.firstError = nil
                throw firstError
            }
        }
    }
}
